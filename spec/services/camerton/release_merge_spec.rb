require "rails_helper"

RSpec.describe Camerton::ReleaseMerge do
  let(:chat) { create(:chat) }
  let!(:original) { create(:release, :resolved, artist: "Nickelback", title: "Follow You Home") }
  let(:duplicate) { create(:release, :resolved, artist: " nickelback", title: "FOLLOW YOU HOME ") }

  def merge(release = duplicate)
    described_class.new(release).call
  end

  it "moves the shares to the oldest release of the same kind, artist and title, ignoring case and spaces" do
    create(:release, :resolved, artist: "Nickelback", title: "Follow You Home")
    share = create(:release_share, chat: chat, release: duplicate)

    expect(merge).to eq(original)
    expect(share.reload.release).to eq(original)
    expect(duplicate.reload.merged_into).to eq(original)
  end

  it "moves a review the member had only for the duplicate, keeping its score" do
    review = create(:review, chat: chat, release: duplicate, score: 5)

    merge

    expect(review.reload).to have_attributes(release: original, score: 5)
    expect(ScoreReviewJob).not_to have_been_enqueued
  end

  it "joins a member's two reviews into the original's and re-scores it silently" do
    kept = create(:review, chat: chat, release: original, score: 9)
    old_message = create(:review_message, review: kept)
    gone = create(:review, chat: chat, user: kept.user, release: duplicate, score: 5)
    moved_message = create(:review_message, review: gone)

    merge

    expect(Review.exists?(gone.id)).to be(false)
    expect(kept.messages).to contain_exactly(old_message, moved_message)
    expect(moved_message.reload.release_share.release).to eq(original)
    expect(ScoreReviewJob).to have_been_enqueued.with(kept, react: false)
  end

  it "keeps reviews of the same member in other chats apart" do
    here = create(:review, chat: chat, release: original)
    elsewhere = create(:review, user: here.user, release: duplicate)

    merge

    expect(elsewhere.reload.release).to eq(original)
    expect(ScoreReviewJob).not_to have_been_enqueued
  end

  it "leaves a song and an album of the same name apart" do
    album = create(:release, :resolved, :album, artist: "Nickelback", title: "Follow You Home")

    expect(merge(album)).to be_nil
    expect(album.reload.merged_into).to be_nil
  end

  it "doesn't merge without both an artist and a title, or before the release is resolved" do
    expect(merge(create(:release, :resolved, artist: nil, title: "Follow You Home"))).to be_nil
    expect(merge(create(:release, artist: "Nickelback", title: "Follow You Home"))).to be_nil
  end

  it "doesn't merge into a release that was itself merged, and is a no-op the second time" do
    merge
    third = create(:release, :resolved, artist: "Nickelback", title: "Follow You Home")

    expect(merge(third)).to eq(original)
    expect(merge(duplicate)).to be_nil
  end

  it "finds links of a merged release under the original" do
    merge
    link = Camerton::Link.new(platform: duplicate.platform, external_id: duplicate.external_id, kind: "song", url: duplicate.url)

    expect(Release.find_for(link)).to eq(original)
    expect(Release.find_or_create_for(link)).to eq(original)
  end
end
