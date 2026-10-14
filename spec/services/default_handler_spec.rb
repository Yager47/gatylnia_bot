require "rails_helper"

RSpec.describe DefaultHandler do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
  end

  describe "reply priority" do
    def sent_texts
      fake_telegram.sent_messages.map { |params| params[:text] }
    end

    # Every random roll succeeds: Includes, AI and the random Chance line all
    # get their turn unless something earlier answers or stops the chain.
    before { allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(true) }

    it "lets the first responder that answers win" do
      dispatch(message_update(text: "Ало"))

      expect(sent_texts).to eq([ "Ало" ])
    end

    it "treats an empty AI reply as stop: no random line after it" do
      allow(Ai).to receive(:reply_in).and_return("")

      dispatch(message_update(text: "абв"))

      expect(sent_texts).to be_empty
    end

    it "sends a random line when nothing answered (AI rate-limited)" do
      rate_limited = OpenAI::Errors::RateLimitError.new(
        url: URI("https://api.openai.com"), status: 429, headers: {}, body: nil, request: nil, response: nil
      )
      allow(Ai).to receive(:reply_in).and_raise(rate_limited)

      dispatch(message_update(text: "абв"))

      expect(sent_texts.size).to eq(1)
    end

    it "stops after handing a coffee message to its job: no random line" do
      dispatch(message_update(text: "Перша кава"))

      expect(TrackCoffeeTextJob).to have_been_enqueued
      expect(sent_texts).to be_empty
    end

    it "lets a stop rule in Includes stop the chain" do
      dispatch(message_update(text: "Рисова каша"))

      expect(sent_texts).to be_empty
    end
  end

  describe "whom the AI answers" do
    before { allow(Ai).to receive(:reply_in).and_return("…") }

    def sent_texts
      fake_telegram.sent_messages.map { |params| params[:text] }
    end

    def reply_to(message_id, from: { id: 999, is_bot: false, first_name: "Artem" })
      { message_id: message_id, date: Time.current.to_i, chat: telegram_chat, from: from, text: "раніше" }
    end

    it "stays out of a reply to someone else, random line included" do
      allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(true)

      dispatch(message_update(text: "а тобі напевно жопа", reply_to_message: reply_to(5)))

      expect(Ai).not_to have_received(:reply_in)
      expect(sent_texts).to be_empty
    end

    it "answers a reply to the bot without rolling the dice" do
      allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(false)
      create(:message, chat: create(:chat, telegram_id: telegram_chat[:id]), role: :assistant, user: nil, telegram_message_id: 5)

      dispatch(message_update(text: "сам такий", reply_to_message: reply_to(5, from: { id: 1, is_bot: true, first_name: "Гатильня" })))

      expect(sent_texts).to eq([ "…" ])
    end
  end

  describe "coffee messages" do
    it "hands a possible coffee message to the job and replies nothing itself" do
      freeze_time do
        dispatch(message_update(text: "Перша кава", message_id: 77))

        expect(TrackCoffeeTextJob).to have_been_enqueued.with(Message.find_by!(telegram_message_id: 77), sent_at: Time.current)
      end
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "still answers the stats command" do
      dispatch(message_update(text: "@test_bot кава за тиждень"))

      expect(TrackCoffeeTextJob).not_to have_been_enqueued
      expect(fake_telegram.sent_messages.map { |params| params[:text] }).to eq([ "Кава за поточний тиждень:\n\nНікого." ])
    end

    it "doesn't track an edited message again" do
      allow(Ai).to receive(:reply_in).and_return("Шо ти редагуєш")

      dispatch(edited_message_update(text: "Перша кава"))

      expect(TrackCoffeeTextJob).not_to have_been_enqueued
    end

    it "no longer jokes about coffee" do
      expect(Response::Includes.new(user: build(:user), text: "кава").call).to be_nil
    end
  end

  describe "видали каву" do
    let(:sender) { User.find_by!(telegram_id: telegram_from[:id].to_s) }

    def sent_texts
      fake_telegram.sent_messages.map { |params| params[:text] }
    end

    # Creates the chat and the sender the way a first message would.
    def chat
      @chat ||= begin
        allow(Ai).to receive(:reply_in).and_return("…")
        dispatch(message_update(text: "привіт", message_id: 1))
        fake_telegram.sent_messages.clear
        Chat.sole
      end
    end

    it "removes the sender's latest coffee in this chat and shows today's total" do
      travel_to Time.zone.local(2026, 10, 12, 12, 0) # midday, so both cups are "today"
      older = create(:activity, chat: chat, user: sender, occurred_at: 2.hours.ago)
      latest = create(:activity, chat: chat, user: sender, occurred_at: 1.hour.ago, source: :video_note)

      dispatch(message_update(text: "Видали каву", message_id: 2))

      expect(Activity.exists?(latest.id)).to be(false)
      expect(Activity.exists?(older.id)).to be(true)
      expect(sent_texts).to eq([ "Видалив твою останню каву. Сьогодні: 1" ])
      expect(TrackCoffeeTextJob).not_to have_been_enqueued
    end

    it "leaves push-ups, other people's coffee and other chats alone" do
      push_ups = create(:activity, :push_ups, chat: chat, user: sender)
      someone_elses = create(:activity, chat: chat)
      other_chat = create(:activity, user: sender)

      dispatch(message_update(text: "видали каву", message_id: 2))

      expect(Activity.where(id: [ push_ups.id, someone_elses.id, other_chat.id ]).count).to eq(3)
      expect(sent_texts).to eq([ "Ти ще тут не пив каву" ])
    end

    it "doesn't remove another cup when the message is edited" do
      create_list(:activity, 2, chat: chat, user: sender)

      dispatch(edited_message_update(text: "видали каву", message_id: 2))

      expect(Activity.count).to eq(2)
    end
  end

  describe "counting a gato" do
    it "adds an AI comment to the confirmation when the roll hits" do
      allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(true)
      allow(Ai).to receive(:reply_in).and_return("Йди мий руки.")

      dispatch(message_update(text: "Погатив", message_id: 5))

      expect(fake_telegram.sent_messages.map { |params| params[:text] }).to eq([ "Гатіння зараховано. Йди мий руки." ])
      expect(Ai).to have_received(:reply_in).with(Chat.sole, target: Message.find_by!(telegram_message_id: 5), note: Response::Gato::AI_NOTE)
    end
  end

  describe "gato on edited messages" do
    before { allow(Ai).to receive(:reply_in).and_return("…") }

    it "doesn't count a gato again when the message is edited" do
      dispatch(message_update(text: "погатив", message_id: 5))
      dispatch(edited_message_update(text: "погатив", message_id: 5))

      expect(Entry.count).to eq(1)
    end

    it "doesn't delete another gato when the message is edited" do
      dispatch(message_update(text: "погатив", message_id: 5))
      dispatch(message_update(text: "погатив", message_id: 6))
      dispatch(edited_message_update(text: "видали гатіння", message_id: 7))

      expect(Entry.count).to eq(2)
    end
  end

  describe "edited messages" do
    before do
      allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(false)
      allow(Ai).to receive(:reply_in).and_return("Шо ти редагуєш")
    end

    it "answers an edit made within a minute, even if it is processed later" do
      sent_at = Time.current
      travel_to(sent_at + 5.minutes)

      dispatch(edited_message_update(text: "@test_bot абв", date: sent_at.to_i, edit_date: (sent_at + 30.seconds).to_i))

      expect(fake_telegram.sent_messages.size).to eq(1)
    end

    it "ignores an edit made more than a minute after the message" do
      sent_at = Time.current

      dispatch(edited_message_update(text: "@test_bot абв", date: sent_at.to_i, edit_date: (sent_at + 2.minutes).to_i))

      expect(fake_telegram.sent_messages).to be_empty
    end
  end

  describe "video notes" do
    let(:video_note) { { file_id: "file-1", file_unique_id: "u1", duration: 10, length: 400 } }

    it "records the message and hands the video to the job without replying" do
      freeze_time do
        dispatch(message_update(text: nil, message_id: 88, video_note: video_note))

        message = Message.find_by!(telegram_message_id: 88)
        expect(message.content).to eq("Петро Тест записав відео 10s.")
        expect(HandleVideoNoteJob).to have_been_enqueued.with(message, file_id: "file-1", duration: 10, sent_at: Time.current)
      end
      expect(fake_telegram.sent_messages).to be_empty
    end

    it "ignores Telegram re-sending a video note as an edit" do
      dispatch(edited_message_update(text: nil, video_note: video_note))

      expect(HandleVideoNoteJob).not_to have_been_enqueued
      expect(Message.count).to eq(0)
    end
  end
end
