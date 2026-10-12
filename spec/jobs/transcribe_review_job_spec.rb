require "rails_helper"

RSpec.describe TranscribeReviewJob do
  let(:share) { create(:release_share, telegram_message_id: 42) }
  let(:user) { create(:user, chats: [ share.chat ]) }
  let(:sent_at) { Time.zone.local(2026, 10, 13, 18, 0) }

  def perform(source: "voice", caption: nil)
    described_class.perform_now(
      share, user, telegram_message_id: 100, file_id: "file-1", source: source, caption: caption, sent_at: sent_at
    )
  end

  def transcribes_to(text)
    allow(TelegramFileDownloader).to receive(:download) do |_file_id, dir:|
      File.join(dir, "telegram.oga").tap { |path| File.write(path, "audio") }
    end
    allow(Video::NoteTranscriber).to receive(:call).and_return(text)
  end

  it "stores the transcript as the member's review message and has it scored" do
    transcribes_to(" ну це топчик, дев'ять з десяти ")

    perform

    review = Review.sole
    expect(review).to have_attributes(chat: share.chat, release: share.release, user: user)
    expect(review.messages.sole).to have_attributes(
      release_share: share, telegram_message_id: 100, source: "voice", text: "ну це топчик, дев'ять з десяти", sent_at: sent_at
    )
    expect(ScoreReviewJob).to have_been_enqueued.with(review)
    expect(TelegramFileDownloader).to have_received(:download).with("file-1", dir: anything)
  end

  it "keeps a caption before the transcript" do
    transcribes_to("кайфова штука")

    perform(source: "video_note", caption: "дивіться")

    expect(ReviewMessage.sole).to have_attributes(source: "video_note", text: "дивіться\nкайфова штука")
  end

  it "removes the downloaded file afterwards" do
    downloaded = nil
    allow(TelegramFileDownloader).to receive(:download) do |_file_id, dir:|
      downloaded = File.join(dir, "telegram.oga").tap { |path| File.write(path, "audio") }
    end
    allow(Video::NoteTranscriber).to receive(:call).and_return("норм")

    perform

    expect(File.exist?(downloaded)).to be(false)
  end

  it "stores nothing when nothing was said" do
    transcribes_to("  ")

    perform

    expect([ Review.count, ReviewMessage.count ]).to eq([ 0, 0 ])
    expect(ScoreReviewJob).not_to have_been_enqueued
  end

  it "doesn't download or transcribe again once the message is stored" do
    review = create(:review, chat: share.chat, release: share.release, user: user)
    create(:review_message, review: review, release_share: share, telegram_message_id: 100)
    allow(TelegramFileDownloader).to receive(:download)

    perform

    expect(TelegramFileDownloader).not_to have_received(:download)
  end

  it "retries when the file can't be downloaded" do
    allow(TelegramFileDownloader).to receive(:download).and_raise(TelegramFileDownloader::Error, "Telegram file download failed: 502")

    perform

    expect(ReviewMessage.count).to eq(0)
    expect(described_class).to have_been_enqueued
  end

  it "transcribes one reply at a time" do
    expect(described_class.concurrency_limit).to eq(1)
  end
end
