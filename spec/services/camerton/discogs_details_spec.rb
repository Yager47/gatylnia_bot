require "rails_helper"

RSpec.describe Camerton::DiscogsDetails do
  let(:discogs) { instance_double(Camerton::Discogs) }
  let(:release) { create(:release, :resolved) }

  def add_details
    described_class.new(release, discogs: discogs).call
  end

  def discogs_finds_master
    allow(discogs).to receive_messages(
      search_masters: [ { "id" => 7, "year" => "1975", "format" => [ "Album" ] } ],
      master: { "id" => 7, "title" => "A Night At The Opera", "year" => 1975, "genres" => [ "Rock" ], "styles" => [ "Art Rock" ] }
    )
  end

  around { |example| travel_to(Time.zone.local(2026, 10, 14, 12)) { example.run } }

  it "stores what Discogs found and when it asked" do
    discogs_finds_master

    add_details

    expect(release.reload).to have_attributes(
      discogs_master_id: 7, year: 1975, album_title: "A Night At The Opera",
      genres: [ "Rock" ], styles: [ "Art Rock" ], discogs_checked_at: Time.current
    )
  end

  it "remembers asking when nothing matched" do
    allow(discogs).to receive(:search_masters).and_return([])

    add_details

    expect(release.reload).to have_attributes(discogs_checked_at: Time.current, discogs_master_id: nil, year: nil)
  end

  it "asks only once per release" do
    discogs_finds_master

    2.times { described_class.new(Release.find(release.id), discogs: discogs).call }

    expect(discogs).to have_received(:search_masters).once
  end

  it "skips a release without a name or an artist" do
    allow(discogs).to receive(:search_masters)

    [ create(:release), create(:release, status: :unresolvable), create(:release, :resolved, artist: nil) ].each do |release|
      described_class.new(release, discogs: discogs).call
    end

    expect(discogs).not_to have_received(:search_masters)
  end

  it "logs a Discogs failure and leaves the release to be asked again" do
    allow(discogs).to receive(:search_masters).and_raise(Camerton::Discogs::TransientError, "Discogs answered 429")
    allow(Rails.logger).to receive(:warn)

    expect { add_details }.not_to raise_error

    expect(release.reload.discogs_checked_at).to be_nil
    expect(Rails.logger).to have_received(:warn).with(/Release #{release.id}: Camerton::Discogs::TransientError: Discogs answered 429/)
  end
end
