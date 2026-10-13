require "rails_helper"

RSpec.describe Camerton::ReviewRecorder do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
  end

  let!(:chat) { create(:chat, telegram_id: telegram_chat[:id].to_s, mode: :quiet, camerton_enabled: true) }
  let(:release) { create(:release, :resolved) }
  let!(:share) { create(:release_share, chat: chat, release: release, telegram_message_id: 42, announcement_telegram_message_id: 43) }

  def reply_update(text:, to: 42, message_id: 100, **attrs)
    message_update(text: text, message_id: message_id, reply_to_message: { message_id: to }, **attrs)
  end

  it "stores a reply to the shared link exactly as written and has it scored" do
    sent_at = Time.zone.local(2026, 10, 13, 18, 0)

    dispatch(reply_update(text: "Ну це прям 🔥, 9/10", date: sent_at.to_i))

    review = Review.sole
    expect(review).to have_attributes(chat: chat, release: release, user: User.find_by!(telegram_id: "555"), score: nil)
    expect(review.messages.sole).to have_attributes(
      release_share: share, telegram_message_id: 100, source: "text", text: "Ну це прям 🔥, 9/10", sent_at: sent_at
    )
    expect(ScoreReviewJob).to have_been_enqueued.with(review)
  end

  it "counts a reply to the bot's announcement too" do
    dispatch(reply_update(text: "мід", to: 43))

    expect(Review.sole.messages.sole.release_share).to eq(share)
  end

  it "widens the same review with a second reply" do
    dispatch(reply_update(text: "спочатку не зайшло", message_id: 100))
    dispatch(reply_update(text: "а на третій раз кайф", message_id: 101))

    expect(Review.sole.messages.order(:id).pluck(:text)).to eq([ "спочатку не зайшло", "а на третій раз кайф" ])
    expect(ScoreReviewJob).to have_been_enqueued.with(Review.sole).twice
  end

  it "widens the same review from a reply under a later share, remembering which share" do
    reshare = create(:release_share, chat: chat, release: release, telegram_message_id: 200)

    dispatch(reply_update(text: "перший раз: 5", to: 42, message_id: 100))
    dispatch(reply_update(text: "тепер вже 8", to: 200, message_id: 201))

    expect(Review.sole.messages.order(:id).map(&:release_share)).to eq([ share, reshare ])
  end

  it "counts a reply to an older link the bot knows only from an import, by the link it replies to" do
    imported = create(:release_share, chat: chat, release: release, telegram_message_id: 900_001, shared_at: 1.year.ago)
    old_link = { message_id: 14_210, from: telegram_from, text: "заціни #{release.url}" }

    dispatch(message_update(text: "7/10, досі слухаю", message_id: 100, reply_to_message: old_link))

    expect(ReviewMessage.sole).to have_attributes(release_share: imported, text: "7/10, досі слухаю")
    expect(ScoreReviewJob).to have_been_enqueued.with(Review.sole)
  end

  it "keeps separate reviews per chat" do
    other_chat = create(:chat, telegram_id: "-100777", camerton_enabled: true, mode: :quiet)
    create(:release_share, chat: other_chat, release: release, telegram_message_id: 42)

    dispatch(reply_update(text: "топ"))
    dispatch(reply_update(text: "топ", chat: telegram_chat(id: -100_777)))

    expect(Review.where(release: release).pluck(:chat_id)).to contain_exactly(chat.id, other_chat.id)
  end

  it "replaces the text and re-scores when the reply is edited" do
    dispatch(reply_update(text: "6/10"))
    clear_enqueued_jobs

    dispatch(edited_message_update(text: "7/10", message_id: 100, reply_to_message: { message_id: 42 }))

    expect(ReviewMessage.sole.text).to eq("7/10")
    expect(ScoreReviewJob).to have_been_enqueued.with(Review.sole)
  end

  it "doesn't store or score a redelivered reply again" do
    dispatch(reply_update(text: "6/10"))
    clear_enqueued_jobs

    dispatch(reply_update(text: "6/10"))

    expect(ReviewMessage.count).to eq(1)
    expect(ScoreReviewJob).not_to have_been_enqueued
  end

  it "treats a reply that shares a new link as a share, not feedback" do
    dispatch(reply_update(text: "краще ось це https://music.youtube.com/watch?v=lYBUbBu4W08"))

    expect(Review.count).to eq(0)
    expect(ReleaseShare.count).to eq(2)
  end

  it "ignores replies without text, replies to other messages and plain messages" do
    dispatch(message_update(message_id: 100, text: nil, sticker: { file_id: "x" }, reply_to_message: { message_id: 42 }))
    dispatch(reply_update(text: "ахаха", to: 999, message_id: 101))
    dispatch(message_update(text: "просто кажу", message_id: 102))

    expect([ Review.count, ReviewMessage.count ]).to eq([ 0, 0 ])
  end

  describe "voice and video notes" do
    it "transcribes a voice reply in the background" do
      sent_at = Time.zone.local(2026, 10, 13, 18, 0)

      dispatch(message_update(
        text: nil, message_id: 100, date: sent_at.to_i, reply_to_message: { message_id: 42 },
        voice: { file_id: "voice-1", duration: 7, mime_type: "audio/ogg" }
      ))

      expect(TranscribeReviewJob).to have_been_enqueued.with(
        share, User.find_by!(telegram_id: "555"),
        telegram_message_id: 100, file_id: "voice-1", source: "voice", caption: nil, sent_at: sent_at
      )
      expect(ReviewMessage.count).to eq(0)
    end

    it "transcribes a video note reply to the announcement, passing a caption along" do
      dispatch(message_update(
        text: nil, caption: "дивіться", message_id: 101, reply_to_message: { message_id: 43 },
        video_note: { file_id: "note-1", duration: 12, length: 384 }
      ))

      expect(TranscribeReviewJob).to have_been_enqueued
        .with(share, anything, hash_including(file_id: "note-1", source: "video_note", caption: "дивіться"))
    end

    it "doesn't transcribe a video note again when Telegram re-sends it as an edit" do
      dispatch(edited_message_update(
        text: nil, message_id: 101, reply_to_message: { message_id: 42 },
        video_note: { file_id: "note-1", duration: 12, length: 384 }
      ))

      expect(TranscribeReviewJob).not_to have_been_enqueued
    end

    context "in a chat in the default mode" do
      before { chat.update!(mode: :default) }

      let(:video_note) { { file_id: "note-1", duration: 12, length: 384 } }

      it "leaves a video note review to Camerton alone, so it's transcribed once" do
        dispatch(message_update(text: nil, message_id: 101, reply_to_message: { message_id: 42 }, video_note: video_note))

        expect(TranscribeReviewJob).to have_been_enqueued
        expect(HandleVideoNoteJob).not_to have_been_enqueued
        expect(Message.count).to eq(0)
      end

      it "leaves a re-sent video note review alone too" do
        dispatch(edited_message_update(
          text: nil, message_id: 101, date: 10.seconds.ago.to_i, reply_to_message: { message_id: 42 }, video_note: video_note
        ))

        expect(HandleVideoNoteJob).not_to have_been_enqueued
      end

      it "still analyzes a video note that isn't a review" do
        dispatch(message_update(text: nil, message_id: 102, video_note: video_note))

        expect(HandleVideoNoteJob).to have_been_enqueued
        expect(TranscribeReviewJob).not_to have_been_enqueued
      end

      it "leaves voice and text reviews to Camerton alone too: no canned or AI replies" do
        dispatch(message_update(text: nil, message_id: 103, reply_to_message: { message_id: 42 }, voice: { file_id: "v", duration: 3 }))
        dispatch(reply_update(text: "Ало, 5/10", message_id: 104))
        dispatch(edited_message_update(text: "Ало, 6/10", message_id: 104, reply_to_message: { message_id: 42 }))

        expect(TranscribeReviewJob).to have_been_enqueued
        expect(ReviewMessage.sole.text).to eq("Ало, 6/10")
        expect(fake_telegram.sent_messages).to be_empty
        expect(Message.count).to eq(0)
      end

      it "still lets the mode handler answer a reply that isn't feedback" do
        allow_any_instance_of(DefaultHandler).to receive(:chance).and_return(false)
        dispatch(message_update(text: nil, message_id: 105, reply_to_message: { message_id: 42 }, sticker: { file_id: "s" }))
        dispatch(reply_update(text: "Ало", to: 999, message_id: 106))

        expect(fake_telegram.sent_messages.map { |m| m[:text] }).to eq([ "Ало" ])
      end
    end

    it "ignores a voice message that isn't a reply to a share" do
      dispatch(message_update(text: nil, message_id: 102, voice: { file_id: "voice-2", duration: 3 }))

      expect(TranscribeReviewJob).not_to have_been_enqueued
    end
  end

  it "does nothing in a chat with Camerton off" do
    chat.update!(camerton_enabled: false)

    dispatch(reply_update(text: "9/10"))

    expect(Review.count).to eq(0)
  end
end
