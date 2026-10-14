require "rails_helper"

RSpec.describe Camerton::DiscogsLookup do
  let(:discogs) { instance_double(Camerton::Discogs) }
  let(:release) { build(:release, :resolved, artist: "Queen", title: "Bohemian Rhapsody") }
  let(:master) { { "id" => 7, "title" => "A Night At The Opera", "year" => 1975, "genres" => [ "Rock" ], "styles" => [ "Art Rock", "Prog Rock" ] } }

  def hit(id, year, *format)
    { "id" => id, "year" => year.to_s, "format" => format }
  end

  def lookup(hits)
    allow(discogs).to receive(:search_masters).and_return(hits)
    allow(discogs).to receive(:master) { |id| master.merge("id" => id) }

    described_class.new(release, discogs: discogs).call
  end

  def picked(hits)
    lookup(hits)&.master_id
  end

  it "searches a song by track and an album by its title, without version labels" do
    allow(discogs).to receive_messages(search_masters: [], master: nil)

    described_class.new(build(:release, :resolved, title: "Uptown Top Ranking (Remastered 2001) [Live]"), discogs: discogs).call
    described_class.new(build(:release, :album, status: :resolved, artist: "Talk Talk", title: "It's My Life"), discogs: discogs).call

    expect(discogs).to have_received(:search_masters).with(artist: "Queen", track: "Uptown Top Ranking")
    expect(discogs).to have_received(:search_masters).with(artist: "Talk Talk", release_title: "It's My Life")
  end

  it "returns the master's year, genres, styles and, for a song, its album" do
    expect(lookup([ hit(7, 1975, "Vinyl", "LP", "Album") ])).to eq(
      described_class::Result.new(master_id: 7, year: 1975, album_title: "A Night At The Opera", genres: [ "Rock" ], styles: [ "Art Rock", "Prog Rock" ])
    )
  end

  it "picks a song's earliest album over earlier singles, compilations and bootlegs" do
    hits = [
      hit(1, 1992, "Cassette", "Single"),
      hit(2, 1974, "Vinyl", "LP", "Compilation"),
      hit(3, 1973, "Vinyl", "LP", "Album", "Unofficial Release"),
      hit(4, 1981, "CD", "Album"),
      hit(5, 1975, "Vinyl", "LP", "Album"),
      hit(6, "", "Vinyl", "LP", "Album")
    ]

    expect(picked(hits)).to eq(5)
  end

  it "falls back to the earliest single when a song is on no album" do
    expect(picked([ hit(1, 1990, "Vinyl", "7\"", "Single"), hit(2, 1988, "Vinyl", "12\"", "Single") ])).to eq(2)
  end

  it "takes a bootleg when there is nothing official" do
    expect(picked([ hit(1, 2004, "Cassette", "Album", "Unofficial Release") ])).to eq(1)
  end

  it "takes the first hit when none has a year" do
    expect(picked([ hit(1, "", "CD", "Album"), hit(2, "", "CD", "Album") ])).to eq(1)
  end

  it "doesn't name an album for a single, an album release, or an album named after the song" do
    expect(lookup([ hit(1, 1988, "Vinyl", "Single") ]).album_title).to be_nil

    master["title"] = "bohemian rhapsody"
    expect(lookup([ hit(1, 1975, "Vinyl", "Album") ]).album_title).to be_nil

    release.kind = :album
    master["title"] = "A Night At The Opera"
    expect(lookup([ hit(1, 1975, "Vinyl", "Album") ]).album_title).to be_nil
  end

  it "drops a Non-Music genre and an unknown year" do
    master.merge!("genres" => [ "Jazz", "Non-Music" ], "year" => 0)

    expect(lookup([ hit(1, 2001, "Album") ])).to have_attributes(genres: [ "Jazz" ], year: nil)
  end

  it "returns nil when nothing matches or the master is gone" do
    expect(lookup([])).to be_nil

    allow(discogs).to receive_messages(search_masters: [ hit(1, 1975, "Album") ], master: nil)
    expect(described_class.new(release, discogs: discogs).call).to be_nil
  end
end
