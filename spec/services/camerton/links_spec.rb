require "rails_helper"

RSpec.describe Camerton::Links do
  def first_in(**message)
    described_class.first_in(message.with_indifferent_access)
  end

  it "finds a YouTube Music song link in the text and drops tracking parameters" do
    link = first_in(text: "заціни https://music.youtube.com/watch?v=lYBUbBu4W08&si=AbC123 🔥")

    expect(link).to eq(Camerton::Link.new(
      platform: "youtube_music", kind: :song, external_id: "lYBUbBu4W08",
      url: "https://music.youtube.com/watch?v=lYBUbBu4W08"
    ))
  end

  it "finds an album link" do
    link = first_in(text: "https://music.youtube.com/playlist?list=OLAK5uy_nMr9h2VlS-2PULNz3M3XVXQj_P3C2bqaY&si=x")

    expect(link).to have_attributes(kind: :album, external_id: "OLAK5uy_nMr9h2VlS-2PULNz3M3XVXQj_P3C2bqaY")
  end

  it "finds a link in a caption" do
    expect(first_in(caption: "https://music.youtube.com/watch?v=lYBUbBu4W08")).to have_attributes(kind: :song)
  end

  it "finds a link hidden behind hyperlinked text" do
    link = first_in(
      text: "оцініть",
      entities: [ { type: "text_link", offset: 0, length: 7, url: "https://music.youtube.com/watch?v=lYBUbBu4W08" } ]
    )

    expect(link).to have_attributes(external_id: "lYBUbBu4W08")
  end

  it "takes the first supported link when there are several" do
    link = first_in(text: "https://example.com https://music.youtube.com/watch?v=aaaaaaaaaaa https://music.youtube.com/watch?v=bbbbbbbbbbb")

    expect(link.external_id).to eq("aaaaaaaaaaa")
  end

  it "ignores links it doesn't support" do
    [
      "https://www.youtube.com/watch?v=lYBUbBu4W08", # plain YouTube, not YouTube Music
      "https://music.youtube.com/playlist?list=PLuserMadeMix123", # a user playlist, not an album
      "https://music.youtube.com/browse/MPREb_abc",
      "https://music.youtube.com/watch?v=short",
      "https://music.youtube.com/watch?v=lYBUbBu4W08%%", # malformed query
      "просто текст"
    ].each do |text|
      expect(first_in(text: text)).to be_nil, text
    end
  end

  it "returns nil for a message without text" do
    expect(first_in(voice: { file_id: "x" })).to be_nil
  end
end
