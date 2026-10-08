require "rails_helper"

# Characterization specs: they pin down how the webhook behaves *before* the
# milestone-1 refactor (auth, dedup, background job). Examples tagged
# "KNOWN BUG" describe current behaviour we intend to change; when a later
# step fixes it, the expectation flips in the same commit.
RSpec.describe "Telegram webhook", type: :request do
  let(:chat_telegram_id) { -1_001_234_567_890 }

  def post_update(payload, token: "any-token")
    post "/telegram/#{token}/webhook", params: payload, as: :json
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
    before { create_known_sender }

    it "accepts any value in the token path segment (KNOWN BUG: no auth, fixed in step 1)" do
      post_update(message_update(text: "просто кажу"), token: "definitely-not-the-secret")

      expect(response).to have_http_status(:ok)
      expect(Message.count).to eq(1)
    end
  end

  describe "message from a sender the bot has never seen" do
    # DefaultHandler#create_user returns the result of save! (true) instead of
    # the user, so set_user calls true.chats. The user row is already saved.
    it "saves the chat and user, then crashes (KNOWN BUG: create_user returns true)" do
      expect { post_update(message_update(text: "просто кажу")) }
        .to raise_error(NoMethodError, /chats/)

      expect(Chat.sole).to have_attributes(telegram_id: chat_telegram_id.to_s, telegram_type: "supergroup", title: "Гатильня")
      expect(User.sole).to have_attributes(telegram_id: "555", username: "petro", first_name: "Петро")
      expect(ChatUser.count).to eq(0)
      expect(Message.count).to eq(0)
    end

    it "succeeds when Telegram redelivers the update, which hides the bug in production" do
      payload = message_update(text: "просто кажу")
      expect { post_update(payload) }.to raise_error(NoMethodError)

      post_update(payload)

      expect(response).to have_http_status(:ok)
      expect(Chat.sole.users).to contain_exactly(User.sole)
      expect(Message.count).to eq(1)
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

      expect(Ai).to have_received(:reply_in).with(Chat.sole, vision_frame_path: nil)
      expect(fake_telegram.sent_messages).to eq([ { chat_id: chat_telegram_id.to_s, text: "Відповідь ШІ" } ])
    end

    it "stores a redelivered update once but replies twice (KNOWN BUG: fixed by dedup in steps 3-4)" do
      payload = message_update(update_id: 7, text: "Ало", message_id: 42)

      2.times { post_update(payload) }

      expect(Message.where(role: :user).count).to eq(1)
      expect(fake_telegram.sent_messages.size).to eq(2)
    end

    it "fails on a private chat because Chat requires a title (KNOWN BUG: ignored from step 5)" do
      private_chat = telegram_chat(id: 555, type: "private", title: nil)

      post_update(message_update(text: "Ало", chat: private_chat))

      expect(response).to have_http_status(:unprocessable_content)
      expect(Chat.count).to eq(0)
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
      expect(Chat.count).to eq(0)
      expect(fake_telegram.sent_messages).to be_empty
    end
  end
end
