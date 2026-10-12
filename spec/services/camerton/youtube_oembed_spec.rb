require "rails_helper"

RSpec.describe Camerton::YoutubeOembed do
  subject(:oembed) { described_class.new }

  def youtube_answers(code, body = "")
    allow(oembed).to receive(:request).and_return([ code, body ])
  end

  it "asks for JSON about the given URL and returns the parsed response" do
    youtube_answers(200, '{"title":"Never Gonna Give You Up","author_name":"Rick Astley - Topic"}')

    data = oembed.fetch("https://music.youtube.com/watch?v=lYBUbBu4W08")

    expect(data).to eq("title" => "Never Gonna Give You Up", "author_name" => "Rick Astley - Topic")
    expect(oembed).to have_received(:request).with(
      URI("https://www.youtube.com/oembed?format=json&url=https%3A%2F%2Fmusic.youtube.com%2Fwatch%3Fv%3DlYBUbBu4W08")
    )
  end

  it "returns nil when YouTube has nothing to embed" do
    [ 400, 401, 403, 404 ].each do |code|
      youtube_answers(code)

      expect(oembed.fetch("https://music.youtube.com/watch?v=lYBUbBu4W08")).to be_nil, code.to_s
    end
  end

  it "raises a transient error on rate limiting and server errors" do
    [ 429, 500, 503 ].each do |code|
      youtube_answers(code)

      expect { oembed.fetch("https://music.youtube.com/watch?v=lYBUbBu4W08") }
        .to raise_error(described_class::TransientError, /#{code}/)
    end
  end

  it "turns network failures into transient errors" do
    allow(oembed).to receive(:request).and_call_original
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

    expect { oembed.fetch("https://music.youtube.com/watch?v=lYBUbBu4W08") }
      .to raise_error(described_class::TransientError, /Net::OpenTimeout/)
  end
end
