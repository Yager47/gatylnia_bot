require "rails_helper"

RSpec.describe Camerton::RatingsImport do
  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:user) { create(:user, chats: [ chat ]) }

  def rating(list_id, artist: "Unwound", title: "Repetition", year: 1996, score: 8)
    described_class::Rating.new(
      url: "https://music.youtube.com/playlist?list=#{list_id}", artist: artist, title: title, year: year, score: score
    )
  end

  def import(*ratings, dry_run: false)
    described_class.new(chat: chat, user: user, ratings: ratings, dry_run: dry_run).call
  end

  it "creates a resolved album and a spreadsheet review for a new link, silently" do
    report = import(rating("OLAK5uy_repetition"))

    release = Release.sole
    expect(release).to have_attributes(
      platform: "youtube_music", external_id: "OLAK5uy_repetition", kind: "album", status: "resolved",
      artist: "Unwound", title: "Repetition", year: 1996, url: "https://music.youtube.com/playlist?list=OLAK5uy_repetition"
    )
    expect(Review.sole).to have_attributes(chat: chat, release: release, user: user, score: 8, source: "spreadsheet")
    expect(Review.sole.messages).to be_empty
    expect(chat.release_shares).to be_empty
    expect(fake_telegram.calls).to be_empty
    expect(ScoreReviewJob).not_to have_been_enqueued
    expect(report).to have_attributes(releases_created: 1, releases_merged: 0, reviews_created: 1, reviews_filled: 0, skipped: {})
  end

  it "scores the release a known link already points to" do
    release = create(:release, :album, :resolved, external_id: "OLAK5uy_known")

    report = import(rating("OLAK5uy_known"))

    expect(Review.sole).to have_attributes(release: release, score: 8)
    expect(Release.count).to eq(1)
    expect(report.releases_created).to eq(0)
  end

  it "scores the chat's release of the same name when the link is another edition" do
    existing = create(:release, :album, :resolved, artist: "The Beatles", title: "Revolver")

    report = import(rating("OLAK5uy_remaster", artist: "the beatles ", title: "Revolver", year: 1966))

    expect(Review.sole.release).to eq(existing)
    expect(Release.find_by!(external_id: "OLAK5uy_remaster").merged_into).to eq(existing)
    expect(report).to have_attributes(releases_created: 0, releases_merged: 1)
  end

  it "fills in a review whose replies gave no score, keeping the replies" do
    release = create(:release, :album, :resolved, external_id: "OLAK5uy_replied")
    review = create(:review, chat: chat, release: release, user: user, score: nil)
    create(:review_message, review: review, text: "де знайшов?")

    report = import(rating("OLAK5uy_replied", score: 6))

    expect(review.reload).to have_attributes(score: 6, source: "spreadsheet")
    expect(review.messages.count).to eq(1)
    expect(report).to have_attributes(reviews_created: 0, reviews_filled: 1)
  end

  it "never replaces a score given in the chat, so it's safe to run again" do
    release = create(:release, :album, :resolved, external_id: "OLAK5uy_scored")
    review = create(:review, chat: chat, release: release, user: user, score: 3)

    report = import(rating("OLAK5uy_scored", score: 10))

    expect(review.reload).to have_attributes(score: 3, source: "telegram")
    expect(report.skipped).to eq(already_scored: [ "Unwound — Repetition" ])
  end

  it "skips links that aren't releases and scores out of range" do
    report = import(
      described_class::Rating.new(url: "https://music.youtube.com/search?q=Unwound", artist: "Unwound", title: "Fake Train", year: 1993, score: 8),
      rating("OLAK5uy_eleven", title: "Too Good", score: 11)
    )

    expect(Release.count).to eq(0)
    expect(Review.count).to eq(0)
    expect(report.skipped).to eq(invalid_links: [ "Unwound — Fake Train" ], invalid_scores: [ "Unwound — Too Good" ])
  end

  it "writes nothing in a dry run but reports what it would do" do
    report = import(rating("OLAK5uy_repetition"), dry_run: true)

    expect(Release.count).to eq(0)
    expect(Review.count).to eq(0)
    expect(report).to have_attributes(releases_created: 1, reviews_created: 1)
  end
end
