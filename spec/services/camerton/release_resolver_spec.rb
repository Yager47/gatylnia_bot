require "rails_helper"

RSpec.describe Camerton::ReleaseResolver do
  let(:cleaner) { instance_double(Camerton::ReleaseNameCleaner) }
  let(:release) { create(:release) }
  let(:source) { Camerton::SourceMetadata.new(title: "Queen – Bohemian Rhapsody (Official Video)", author: "Queen Official") }

  def resolve
    described_class.new(release, cleaner: cleaner).call
  end

  it "stores the cleaned names and the raw ones" do
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata).with(release).and_return(source)
    allow(cleaner).to receive(:call).with(kind: "song", source: source)
      .and_return(Camerton::ReleaseNameCleaner::Result.new(artist: "Queen", title: "Bohemian Rhapsody"))

    resolve

    expect(release.reload).to have_attributes(
      status: "resolved", artist: "Queen", title: "Bohemian Rhapsody",
      source_title: source.title, source_author: "Queen Official"
    )
  end

  it "falls back to the raw title and no artist when the model returns blanks" do
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata).and_return(source)
    allow(cleaner).to receive(:call).and_return(Camerton::ReleaseNameCleaner::Result.new(artist: "", title: ""))

    resolve

    expect(release.reload).to have_attributes(status: "resolved", artist: nil, title: source.title)
  end

  it "marks the release unresolvable without asking the model when the platform has nothing" do
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata).and_return(nil)
    allow(cleaner).to receive(:call)

    resolve

    expect(release.reload).to be_unresolvable
    expect(cleaner).not_to have_received(:call)
  end

  it "does nothing for a release that isn't pending" do
    release.update!(status: :resolved, artist: "Queen", title: "Bohemian Rhapsody")
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata)

    resolve

    expect(Camerton::Platforms::YoutubeMusic).not_to have_received(:source_metadata)
  end
end
