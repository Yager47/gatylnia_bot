require "rails_helper"

# Characterization specs, written before the milestone-1 refactor (auth,
# dedup, background job) and kept passing through it. Examples tagged
# "KNOWN BUG" describe current behaviour we intend to change; when a later
# step fixes it, the expectation flips in the same commit.
RSpec.describe "Telegram webhook", type: :request do
  let(:chat_telegram_id) { -1_001_234_567_890 }

  # Performs the enqueued ProcessTelegramUpdateJob (and any retries it
  # schedules) by default, so examples describe the bot's end-to-end behaviour.
  def post_update(payload, path: "/telegram/webhook", secret: ENV.fetch("TELEGRAM_WEBHOOK_SECRET"), perform_jobs: true)
    headers = secret.nil? ? {} : { "X-Telegram-Bot-Api-Secret-Token" => secret }
    send_request = -> { post path, params: payload, headers: headers, as: :json }
    perform_jobs ? perform_enqueued_jobs(&send_request) : send_request.call
  rescue Minitest::UnexpectedError => e
    # perform_enqueued_jobs wraps exceptions raised inside its block.
    raise e.error
  end

  # Matches telegram_from in spec/support/telegram_payloads.rb.
  def create_known_sender
    create(:user, telegram_id: "555", username: "petro", first_name: "Петро", last_name: "Тест")
  end

  before do
    # DefaultHandler rolls dice (rand) to decide whether to run some
    # responders. Temporary seam until randomness is injectable.
    allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(false)
  end

  describe "authentication" do
    let(:payload) { message_update(text: "Ало") }

    before { create_known_sender }

    def expect_rejected
      expect(response).to have_http_status(:unauthorized)
      expect(Chat.count).to eq(0)
      expect(Message.count).to eq(0)
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "processes an update that carries the secret token" do
      post_update(payload)

      expect(response).to have_http_status(:ok)
      expect(fake_telegram.sent_messages.size).to eq(1)
    end

    it "rejects a request without the secret token header" do
      post_update(payload, secret: nil)

      expect_rejected
    end

    it "rejects a request with a wrong secret token" do
      post_update(payload, secret: "wrong-secret-0123456789abcdef0123")

      expect_rejected
    end

    it "no longer serves the legacy path with the bot token in the URL" do
      post_update(payload, path: "/telegram/any-token/webhook")

      expect(response).to have_http_status(:not_found)
      expect(Message.count).to eq(0)
      expect(fake_telegram.sent_messages).to be_empty
    end

    context "when TELEGRAM_WEBHOOK_SECRET is not set on the server" do
      around do |example|
        original = ENV.delete("TELEGRAM_WEBHOOK_SECRET")
        example.run
      ensure
        ENV["TELEGRAM_WEBHOOK_SECRET"] = original
      end

      it "rejects every request and logs the misconfiguration" do
        allow(Rails.logger).to receive(:error)

        post_update(payload, secret: "")

        expect_rejected
        expect(Rails.logger).to have_received(:error).with(/TELEGRAM_WEBHOOK_SECRET is not set/)
      end
    end
  end

  describe "ingestion" do
    it "stores the update and enqueues its processing instead of doing it in the request" do
      post_update(message_update(update_id: 77, text: "Ало"), perform_jobs: false)

      expect(response).to have_http_status(:ok)
      update = TelegramUpdate.sole
      expect(update).to have_attributes(update_id: 77, update_type: "message", status: "received")
      expect(ProcessTelegramUpdateJob).to have_been_enqueued.with(update.id)
      expect(Message.count).to eq(0)
    end

    it "stores the payload exactly as sent, without Rails' wrapped params" do
      payload = edited_message_update(update_id: 78, text: "Ало")

      post_update(payload, perform_jobs: false)

      update = TelegramUpdate.sole
      expect(update.update_type).to eq("edited_message")
      expect(update.payload).to eq(payload.deep_stringify_keys)
    end

    it "rejects a body without update_id" do
      post_update({ message: { text: "Ало" } }, perform_jobs: false)

      expect(response).to have_http_status(:bad_request)
      expect(TelegramUpdate.count).to eq(0)
      expect(ProcessTelegramUpdateJob).not_to have_been_enqueued
    end

    it "rejects a non-integer update_id" do
      post_update({ update_id: "abc", message: { text: "Ало" } }, perform_jobs: false)

      expect(response).to have_http_status(:bad_request)
      expect(TelegramUpdate.count).to eq(0)
    end
  end

  describe "message from a sender the bot has never seen" do
    it "creates the chat, user and membership and records the message" do
      post_update(message_update(text: "просто кажу"))

      expect(response).to have_http_status(:ok)
      chat = Chat.sole
      user = User.sole
      expect(chat).to have_attributes(telegram_id: chat_telegram_id.to_s, telegram_type: "supergroup", title: "Гатильня")
      expect(user).to have_attributes(telegram_id: "555", username: "petro", first_name: "Петро")
      expect(chat.users).to contain_exactly(user)
      expect(Message.sole).to have_attributes(user: user, content: "просто кажу")
    end

    it "creates the user in an accountant-mode chat too" do
      create(:chat, telegram_id: chat_telegram_id.to_s, mode: :accountant)

      post_update(message_update(text: "просто кажу"))

      expect(response).to have_http_status(:ok)
      expect(Chat.sole.users).to contain_exactly(User.sole)
      expect(Message.sole.user).to eq(User.sole)
    end
  end

  describe "message from a known sender" do
    let!(:sender) { create_known_sender }

    it "reuses the existing chat and user" do
      chat = create(:chat, telegram_id: chat_telegram_id.to_s)
      chat.users << sender

      expect { post_update(message_update(text: "просто кажу")) }
        .not_to change { [ Chat.count, User.count, ChatUser.count ] }
    end

    it "creates the chat and membership when the chat is new" do
      post_update(message_update(text: "просто кажу"))

      expect(response).to have_http_status(:ok)
      expect(Chat.sole.users).to contain_exactly(sender)
    end

    it "records the message and replies to an exact-match phrase" do
      post_update(message_update(text: "Ало", message_id: 42))

      expect(fake_telegram.sent_messages).to eq([ { chat_id: chat_telegram_id.to_s, text: "Ало" } ])

      user_message, bot_message = Message.order(:id).to_a
      expect(user_message).to have_attributes(role: "user", content: "Ало", telegram_message_id: 42)
      expect(bot_message).to have_attributes(role: "assistant", content: "Ало", telegram_message_id: 1001)
    end

    it "records the message without replying when nothing matches" do
      post_update(message_update(text: "просто кажу"))

      expect(Message.sole).to have_attributes(role: "user", content: "просто кажу")
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "replies with AI when the bot is mentioned" do
      allow(Ai).to receive(:reply_in).and_return("Відповідь ШІ")

      post_update(message_update(text: "@test_bot як справи"))

      expect(Ai).to have_received(:reply_in).with(Chat.sole, target: Message.find_by!(role: :user), frame_paths: [])
      expect(fake_telegram.sent_messages).to eq([ { chat_id: chat_telegram_id.to_s, text: "Відповідь ШІ" } ])
    end

    it "processes a redelivered update only once" do
      payload = message_update(update_id: 7, text: "Ало", message_id: 42)

      2.times { post_update(payload) }

      expect(response).to have_http_status(:ok)
      expect(TelegramUpdate.sole).to be_processed
      expect(Message.where(role: :user).count).to eq(1)
      expect(fake_telegram.sent_messages.size).to eq(1)
    end

    it "rolls back a failed send and retries it without double-counting" do
      failures = 0
      allow(fake_telegram).to receive(:send_message).and_wrap_original do |original, **params|
        if failures.zero?
          failures += 1
          raise Faraday::ConnectionFailed, "Telegram unreachable"
        end
        original.call(**params)
      end

      post_update(message_update(update_id: 8, text: "гатю"))

      expect(response).to have_http_status(:ok)
      expect(Entry.count).to eq(1)
      expect(fake_telegram.sent_messages.size).to eq(1)
      expect(TelegramUpdate.sole).to have_attributes(status: "processed", attempts: 2, last_error: nil)
    end

    it "answers Telegram 200 before processing, and retries a failure itself" do
      allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "Telegram unreachable")

      post_update(message_update(update_id: 9, text: "гатю"), perform_jobs: false)
      expect(response).to have_http_status(:ok)

      perform_enqueued_jobs

      expect(Entry.count).to eq(0)
      expect(TelegramUpdate.sole).to have_attributes(status: "failed", attempts: 1, last_error: /Telegram unreachable/)
      expect(ProcessTelegramUpdateJob).to have_been_enqueued.with(TelegramUpdate.sole.id)
    end
  end

  describe "/ping" do
    it "replies pong in a group without recording anything" do
      post_update(command_update("/ping"))

      expect(response).to have_http_status(:ok)
      expect(fake_telegram.sent_messages).to eq([ { chat_id: chat_telegram_id, text: "pong" } ])
      expect(TelegramUpdate.sole).to be_processed
      expect([ Chat.count, User.count, Message.count ]).to eq([ 0, 0, 0 ])
    end

    it "replies to /ping addressed to this bot" do
      post_update(command_update("/ping@test_bot"))

      expect(fake_telegram.sent_messages.map { |m| m[:text] }).to eq([ "pong" ])
    end

    it "leaves /ping addressed to another bot to the regular handlers" do
      create_known_sender

      post_update(command_update("/ping@other_bot"))

      expect(fake_telegram.sent_messages).to be_empty
      expect(Message.sole.content).to eq("/ping@other_bot")
    end

    it "leaves unknown commands to the regular handlers" do
      create_known_sender

      post_update(command_update("/start"))

      expect(fake_telegram.sent_messages).to be_empty
      expect(Message.sole.content).to eq("/start")
    end

    it "doesn't reply again when /ping is edited" do
      create_known_sender
      update = command_update("/ping")
      update[:edited_message] = update.delete(:message).merge(edit_date: Time.current.to_i)

      post_update(update)

      expect(fake_telegram.sent_messages.map { |m| m[:text] }).not_to include("pong")
    end
  end

  describe "messages not sent by a person" do
    let(:group) { telegram_chat }
    let(:anonymous_admin) { telegram_from(id: 1_087_968_824, first_name: "Group", last_name: nil, username: "GroupAnonymousBot").merge(is_bot: true) }

    def expect_ignored
      expect(response).to have_http_status(:ok)
      expect(TelegramUpdate.sole).to be_ignored
      expect([ Chat.count, User.count, ChatUser.count, Message.count ]).to eq([ 0, 0, 0, 0 ])
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "ignores an anonymous admin posting as the group" do
      post_update(message_update(text: "Ало", from: anonymous_admin, sender_chat: group))

      expect_ignored
    end

    it "ignores an anonymous admin's /ping" do
      post_update(command_update("/ping", from: anonymous_admin, sender_chat: group))

      expect_ignored
    end

    it "ignores a post auto-forwarded from a linked channel" do
      telegram = telegram_from(id: 777_000, first_name: "Telegram", last_name: nil, username: nil)
      channel = { id: -1_009_999, type: "channel", title: "Канал" }

      post_update(message_update(text: "Ало", from: telegram, sender_chat: channel, is_automatic_forward: true))

      expect_ignored
    end

    it "still applies a rename done by an anonymous admin" do
      chat = create(:chat, telegram_id: chat_telegram_id.to_s, title: "Стара назва")

      post_update(message_update(text: nil, from: anonymous_admin, sender_chat: group, new_chat_title: "Нова назва"))

      expect(chat.reload.title).to eq("Нова назва")
      expect(User.count).to eq(0)
    end
  end

  describe "private chats" do
    let(:private_chat) { telegram_chat(id: 555, type: "private", title: nil) }

    it "ignores messages without creating anything" do
      post_update(message_update(text: "Ало", chat: private_chat))

      expect(response).to have_http_status(:ok)
      expect(TelegramUpdate.sole).to be_ignored
      expect([ Chat.count, User.count, Message.count ]).to eq([ 0, 0, 0 ])
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "ignores /ping too" do
      post_update(command_update("/ping", chat: private_chat))

      expect(TelegramUpdate.sole).to be_ignored
      expect(fake_telegram.sent_messages).to be_empty
    end
  end

  describe "edited_message" do
    before { create_known_sender }

    it "is handled like a new message when edited within a minute" do
      post_update(edited_message_update(text: "Ало", date: 30.seconds.ago.to_i))

      expect(fake_telegram.sent_messages.map { |m| m[:text] }).to eq([ "Ало" ])
    end

    it "is ignored when edited more than a minute after sending" do
      post_update(edited_message_update(text: "Ало", date: 2.minutes.ago.to_i))

      expect(response).to have_http_status(:ok)
      expect(Message.count).to eq(0)
      expect(fake_telegram.sent_messages).to be_empty
    end
  end

  describe "group upgraded to a supergroup" do
    # Shaped like the real updates from 14 Oct 2026: the new supergroup's
    # message comes from GroupAnonymousBot on behalf of the chat, the old
    # group's from the admin who upgraded it.
    let(:old_group) { telegram_chat(id: -4_828_587_211, type: "group") }
    let(:supergroup) { telegram_chat(id: chat_telegram_id) }
    let(:anonymous_admin) { telegram_from(id: 1_087_968_824, first_name: "Group", last_name: nil, username: "GroupAnonymousBot").merge(is_bot: true) }
    let!(:chat) { create(:chat, telegram_id: "-4828587211", telegram_type: "group", mode: :quiet, camerton_enabled: true) }

    def migrate_from_update(update_id: 1)
      message_update(update_id: update_id, text: nil, message_id: 1, chat: supergroup, from: anonymous_admin, sender_chat: supergroup,
        migrate_from_chat_id: -4_828_587_211)
    end

    def migrate_to_update(update_id: 2)
      message_update(update_id: update_id, text: nil, message_id: 15_174, chat: old_group, migrate_to_chat_id: chat_telegram_id)
    end

    it "points the chat at the supergroup, from either service message, without recording one" do
      post_update(migrate_from_update)

      expect(chat.reload).to have_attributes(telegram_id: chat_telegram_id.to_s, telegram_type: "supergroup", camerton_enabled: true)
      expect(TelegramUpdate.sole).to be_processed

      post_update(migrate_to_update)

      expect(Chat.sole).to eq(chat)
      expect([ Message.count, User.count ]).to eq([ 0, 0 ])
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "dates the migration by the service message and renumbers the old group's messages" do
      upgraded_at = 10.minutes.ago.change(usec: 0)
      old_share = create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: 1.hour.ago)

      post_update(migrate_from_update.deep_merge(message: { date: upgraded_at.to_i }))

      expect(chat.reload.supergroup_since).to eq(upgraded_at)
      expect(old_share.reload.telegram_message_id).to eq(-15_000)
    end

    it "migrates on the old group's message alone, and later messages land on the same chat" do
      post_update(migrate_to_update)
      post_update(message_update(update_id: 3, text: "Ало", message_id: 2, chat: supergroup))

      expect(chat.reload.telegram_id).to eq(chat_telegram_id.to_s)
      expect(Chat.sole.messages.sole.content).to eq("Ало")
    end
  end

  describe "new_chat_title" do
    it "renames a known chat without recording a message" do
      chat = create(:chat, telegram_id: chat_telegram_id.to_s, title: "Стара назва")

      post_update(message_update(text: nil, new_chat_title: "Нова назва"))

      expect(chat.reload.title).to eq("Нова назва")
      expect(Message.count).to eq(0)
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "does nothing for an unknown chat" do
      post_update(message_update(text: nil, new_chat_title: "Нова назва"))

      expect(response).to have_http_status(:ok)
      expect(Chat.count).to eq(0)
    end
  end

  describe "message_reaction" do
    it "stores a user's reaction on a known message" do
      chat = create(:chat, telegram_id: chat_telegram_id.to_s)
      message = create(:message, chat: chat, telegram_message_id: 42)

      post_update({
        update_id: 3,
        message_reaction: {
          chat: telegram_chat,
          message_id: 42,
          user: telegram_from,
          date: Time.current.to_i,
          old_reaction: [],
          new_reaction: [ { type: "emoji", emoji: "👍" } ]
        }
      })

      expect(message.reload.reactions).to eq(
        "users" => { "555" => { "name" => "Петро Тест", "emojis" => [ "👍" ] } },
        "totals" => { "👍" => 1 }
      )
    end
  end

  describe "message_reaction_count" do
    it "stores anonymous reaction totals on a known message" do
      chat = create(:chat, telegram_id: chat_telegram_id.to_s)
      message = create(:message, chat: chat, telegram_message_id: 42)

      post_update({
        update_id: 4,
        message_reaction_count: {
          chat: telegram_chat,
          message_id: 42,
          date: Time.current.to_i,
          reactions: [ { type: { type: "emoji", emoji: "🔥" }, total_count: 3 } ]
        }
      })

      expect(message.reload.reactions).to eq("users" => {}, "totals" => { "🔥" => 3 })
    end
  end

  describe "unsupported update types" do
    it "acknowledges and ignores them" do
      post_update({ update_id: 9, callback_query: { id: "1", data: "x" } })

      expect(response).to have_http_status(:ok)
      expect(TelegramUpdate.sole).to have_attributes(update_type: "callback_query", status: "ignored")
      expect(Chat.count).to eq(0)
      expect(fake_telegram.sent_messages).to be_empty
    end
  end
end
