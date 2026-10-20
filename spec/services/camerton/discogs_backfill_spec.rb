require "rails_helper"

RSpec.describe Camerton::DiscogsBackfill do
  let(:discogs) { instance_double(Camerton::Discogs, requests_per_minute: 25) }
  let(:pauses) { [] }
  let(:output) { StringIO.new }

  def backfill
    described_class.new(discogs: discogs, sleeper: ->(seconds) { pauses << seconds }, output: output).call
  end

  def discogs_finds(genres:, styles:)
    allow(discogs).to receive_messages(
      search_masters: [ { "id" => 7, "year" => "1975", "format" => [ "Album" ] } ],
      master: { "id" => 7, "title" => "A Night At The Opera", "year" => 1975, "genres" => genres, "styles" => styles }
    )
  end

  it "looks up only resolved, unmerged releases never checked" do
    discogs_finds(genres: [ "Rock" ], styles: [ "Art Rock" ])
    unchecked = create(:release, :resolved)
    checked = create(:release, :resolved, discogs_checked_at: 1.day.ago)
    merged = create(:release, :resolved, merged_into: unchecked)
    pending = create(:release)

    report = backfill

    expect(report).to have_attributes(matched: 1, unmatched: 0, failed: 0)
    expect(unchecked.reload).to have_attributes(genres: [ "Rock" ], styles: [ "Art Rock" ], year: 1975)
    expect([ checked, merged, pending ].map { |release| release.reload.genres }).to all(be_nil)
    expect(output.string).to include("#{unchecked.id} 🎵 Queen — Bohemian Rhapsody: Rock, Art Rock")
  end

  it "pauses after each release to stay under the rate limit" do
    discogs_finds(genres: [ "Rock" ], styles: [])
    create_list(:release, 2, :resolved)

    backfill

    expect(pauses).to eq([ 4.8, 4.8 ])
  end

  it "counts a release Discogs doesn't know as checked" do
    allow(discogs).to receive(:search_masters).and_return([])
    release = create(:release, :resolved)

    expect(backfill).to have_attributes(matched: 0, unmatched: 1, failed: 0)
    expect(release.reload.discogs_checked_at).to be_present
  end

  it "leaves a failed release for the next run and waits a full minute" do
    allow(discogs).to receive(:search_masters).and_raise(Camerton::Discogs::TransientError, "Discogs answered 429")
    allow(Rails.logger).to receive(:warn)
    release = create(:release, :resolved)

    expect(backfill).to have_attributes(matched: 0, unmatched: 0, failed: 1)
    expect(release.reload.discogs_checked_at).to be_nil
    expect(described_class.releases).to include(release)
    expect(pauses).to eq([ 60 ])
  end
end
