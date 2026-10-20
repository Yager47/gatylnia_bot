require "rails_helper"

RSpec.describe Achievements::Rules::ReleaseVerdict do
  let(:unanimous) { described_class.new(code: "unanimous", title: "Одностайність", spread: 0..1, wording: "розійшлися не більше ніж на 1 бал") }
  let(:split) { described_class.new(code: "split", title: "Розкол", spread: 6.., wording: "розійшлися на 6+ балів", secret: true) }

  let(:chat) { create(:chat) }
  let(:olya) { create(:user) }
  let(:now) { Time.zone.local(2026, 10, 21, 9) }

  def shared(at:, by: olya)
    create(:release_share, chat: chat, release: create(:release, :resolved), user: by, shared_at: at).release
  end

  def scores(release, *values)
    values.each { |value| create(:review, chat: chat, release: release, score: value) }
  end

  def period(release)
    Achievements::ReleasePeriod.new(release.id)
  end

  it "decides the releases first shared in the chat on the Kyiv day a week ago" do
    week_old = [ shared(at: Time.zone.local(2026, 10, 14, 0, 5)), shared(at: Time.zone.local(2026, 10, 14, 23, 55)) ]
    shared(at: Time.zone.local(2026, 10, 13, 23, 55))
    shared(at: Time.zone.local(2026, 10, 15, 0, 5))
    # Re-shared on the day, but first shared earlier.
    old = shared(at: Time.zone.local(2026, 10, 1))
    create(:release_share, chat: chat, release: old, shared_at: Time.zone.local(2026, 10, 14, 12))

    expect(unanimous.periods(chat, now).map(&:release_id)).to match_array(week_old.map(&:id))
  end

  it "goes to the first sharer when the scores are within 1 point, or 6+ apart, from 2 scores" do
    release = shared(at: now - 7.days)
    create(:release_share, chat: chat, release: release, shared_at: now - 6.days) # a later re-share

    scores(release, 7, 8)
    expect(unanimous.winner_ids(chat, period(release))).to eq([ olya.id ])
    expect(split.winner_ids(chat, period(release))).to be_empty

    scores(release, 2)
    expect(unanimous.winner_ids(chat, period(release))).to be_empty
    expect(split.winner_ids(chat, period(release))).to eq([ olya.id ])
  end

  it "needs at least 2 scores" do
    release = shared(at: now - 7.days)
    scores(release, 5)
    create(:review, chat: chat, release: release, score: nil)

    expect(unanimous.winner_ids(chat, period(release))).to be_empty
  end

  it "names the release in its announcement" do
    release = shared(at: now - 7.days)

    expect(split.line(:awarded, "@olya", nil, period_key: "release-#{release.id}"))
      .to eq("🏆 @olya отримує ачівку «Розкол» за 🎵 Queen — Bohemian Rhapsody: оцінки розійшлися на 6+ балів")
  end
end
