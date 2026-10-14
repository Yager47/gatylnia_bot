require "rails_helper"

RSpec.describe TranscribeNoteJob do
  let(:track) { create(:audio_track, telegram_message_id: 42) }
  let(:user) { create(:user, chats: [ track.chat ]) }
  let(:sent_at) { Time.zone.local(2026, 10, 14, 18, 0) }

  def perform(source: "voice", caption: nil)
    described_class.perform_now(
      track, user, telegram_message_id: 100, file_id: "file-1", source: source, caption: caption, sent_at: sent_at
    )
  end

  def transcribes_to(text)
    allow(TelegramFileDownloader).to receive(:download) do |_file_id, dir:|
      File.join(dir, "telegram.oga").tap { |path| File.write(path, "audio") }
    end
    allow(Video::NoteTranscriber).to receive(:call).and_return(text)
  end

  it "stores the transcript as the member's note on the track" do
    transcribes_to(" бас треба підняти на приспіві ")

    perform

    expect(TrackNote.sole).to have_attributes(
      audio_track: track, user: user, telegram_message_id: 100, source: "voice", text: "бас треба підняти на приспіві", sent_at: sent_at
    )
    expect(TelegramFileDownloader).to have_received(:download).with("file-1", dir: anything)
    expect(fake_telegram.calls.sole).to match([ :set_message_reaction, hash_including(message_id: 100) ])
  end

  it "keeps a caption before the transcript" do
    transcribes_to("ось тут гітара фальшивить")

    perform(source: "video_note", caption: "2:15")

    expect(TrackNote.sole).to have_attributes(source: "video_note", text: "2:15\nось тут гітара фальшивить")
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

    expect(TrackNote.count).to eq(0)
  end

  it "doesn't download or transcribe again once the note is stored" do
    create(:track_note, audio_track: track, user: user, telegram_message_id: 100)
    allow(TelegramFileDownloader).to receive(:download)

    perform

    expect(TelegramFileDownloader).not_to have_received(:download)
  end

  it "retries when the file can't be downloaded" do
    allow(TelegramFileDownloader).to receive(:download).and_raise(TelegramFileDownloader::Error, "Telegram file download failed: 502")

    perform

    expect(TrackNote.count).to eq(0)
    expect(described_class).to have_been_enqueued
  end

  # Solid Queue computes the key from every argument, keywords included; the
  # test adapter never does.
  it "transcribes one reply at a time" do
    job = described_class.new(track, user, telegram_message_id: 100, file_id: "f", source: "voice", caption: nil, sent_at: sent_at)

    expect(job.concurrency_key).to eq(described_class.new(create(:audio_track), user, telegram_message_id: 1, file_id: "g",
                                                          source: "video_note", caption: "x", sent_at: sent_at).concurrency_key)
    expect(described_class.concurrency_limit).to eq(1)
  end
end
