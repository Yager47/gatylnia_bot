require "rails_helper"

RSpec.describe Camerton::Platforms::YoutubeMusic do
  describe ".source_metadata" do
    let(:oembed) { instance_double(Camerton::YoutubeOembed) }

    it "takes a song's title and channel" do
      release = build(:release, external_id: "lYBUbBu4W08", url: "https://music.youtube.com/watch?v=lYBUbBu4W08")
      allow(oembed).to receive(:fetch).with(release.url)
        .and_return("title" => "Never Gonna Give You Up", "author_name" => "Rick Astley - Topic")

      expect(described_class.source_metadata(release, oembed: oembed))
        .to eq(Camerton::SourceMetadata.new(title: "Never Gonna Give You Up", author: "Rick Astley - Topic"))
    end

    it "takes an album's artist from its first track's channel" do
      release = build(:release, :album)
      allow(oembed).to receive(:fetch).with(release.url)
        .and_return("title" => "Album - Revival", "thumbnail_url" => "https://i.ytimg.com/vi/iKLU7z_xdYQ/hqdefault.jpg")
      allow(oembed).to receive(:fetch).with("https://music.youtube.com/watch?v=iKLU7z_xdYQ")
        .and_return("title" => "Walk On Water", "author_name" => "Eminem - Topic")

      expect(described_class.source_metadata(release, oembed: oembed))
        .to eq(Camerton::SourceMetadata.new(title: "Album - Revival", author: "Eminem - Topic"))
    end

    it "leaves an album's artist empty when the first track can't be found" do
      release = build(:release, :album)
      allow(oembed).to receive(:fetch).with(release.url).and_return("title" => "Album - Revival")

      expect(described_class.source_metadata(release, oembed: oembed).author).to be_nil
    end

    it "returns nil when YouTube has no metadata" do
      release = build(:release)
      allow(oembed).to receive(:fetch).and_return(nil)

      expect(described_class.source_metadata(release, oembed: oembed)).to be_nil
    end
  end
end
