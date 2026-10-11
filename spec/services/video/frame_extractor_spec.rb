require "rails_helper"

RSpec.describe Video::FrameExtractor do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  # Stands in for ffmpeg: writes the output file (the last argument) and
  # remembers the -ss timestamp it was asked for.
  def stub_ffmpeg(fail_at: [])
    @seeks = []
    allow(described_class).to receive(:ffmpeg_available?).and_return(true)
    allow(described_class).to receive(:system) do |*args, **|
      seek = args[args.index("-ss") + 1]
      @seeks << seek
      FileUtils.touch(args.last) unless fail_at.include?(seek)
      true
    end
  end

  it "takes frames at the midpoints of equal slices of the video" do
    stub_ffmpeg

    paths = described_class.call("video.mp4", dir: @dir, count: 6, duration: 12)

    expect(@seeks).to eq(%w[1.0 3.0 5.0 7.0 9.0 11.0])
    expect(paths).to eq((0..5).map { |i| File.join(@dir, format("frame_%02d.jpg", i)) })
  end

  it "returns only the frames ffmpeg actually wrote" do
    stub_ffmpeg(fail_at: %w[11.0])

    expect(described_class.call("video.mp4", dir: @dir, count: 6, duration: 12).size).to eq(5)
  end

  it "still extracts frames when Telegram reports no duration" do
    stub_ffmpeg

    expect(described_class.call("video.mp4", dir: @dir, count: 2, duration: nil).size).to eq(2)
  end

  it "returns nothing without ffmpeg" do
    allow(described_class).to receive(:ffmpeg_available?).and_return(false)

    expect(described_class.call("video.mp4", dir: @dir, count: 6, duration: 12)).to eq([])
  end
end
