require "rails_helper"

RSpec.describe Video::NoteAnalyzer do
  let(:user) { build(:user, first_name: "Петро", last_name: nil) }

  def analyze
    Dir.mktmpdir { |dir| described_class.call(video_note: { file_id: "f", duration: 7 }, user: user, dir: dir) }
  end

  it "describes the video with its transcript" do
    allow(TelegramFileDownloader).to receive(:download).and_return("/tmp/video.mp4")
    allow(Video::NoteTranscriber).to receive(:call).and_return("привіт")
    allow(Video::FrameExtractor).to receive(:call).and_return([ "/tmp/frame_00.jpg" ])

    expect(analyze).to have_attributes(description: "Петро записав відео 7s. Транскрипт: привіт.", transcript: "привіт", frame_paths: [ "/tmp/frame_00.jpg" ])
  end

  it "falls back to a plain description when a service fails" do
    allow(TelegramFileDownloader).to receive(:download).and_raise(TelegramFileDownloader::Error, "download failed: 502")

    expect(analyze).to have_attributes(description: "Петро надіслав відео 7s, але не вдалося обробити його вміст.", frame_paths: [])
  end

  it "lets a bug in our own code raise" do
    allow(TelegramFileDownloader).to receive(:download).and_raise(NoMethodError)

    expect { analyze }.to raise_error(NoMethodError)
  end
end
