require "rails_helper"

RSpec.describe DefaultHandler do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
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
      expect(Response::Includes.new(user: build(:user), text: "кава").send(:data).keys.flatten).not_to include("кав")
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
