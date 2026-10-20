require "rails_helper"

# The counting rules besides the song marathons, on one week: Wednesday
# 21 October 2026 is in 2026-W43 (Monday 19 to Sunday 25 October).
RSpec.describe "Achievements::Rules" do
  let(:chat) { create(:chat) }
  let(:now) { Time.zone.local(2026, 10, 21, 12) }
  let(:sharer) { create(:user) }
  let(:olya) { create(:user) }
  let(:petro) { create(:user) }

  def counts(rule_class)
    rule = rule_class.new(code: "test", title: "Тест", goal: 1)
    rule.counts(chat, Achievements::Period.current(rule.period_kind, now: now))
  end

  def share(release = create(:release, :resolved), by: sharer, at: now - 1.day)
    create(:release_share, chat: chat, release: release, user: by, shared_at: at)
  end

  # A reply under the share, added to the member's review of its release.
  def reply(user, share, at:, score: 7, text: "норм", source: :text)
    review = Review.find_by(chat: chat, release: share.release, user: user) ||
      create(:review, chat: chat, release: share.release, user: user, score: score)
    create(:review_message, review: review, release_share: share, sent_at: at, text: text, source: source)
    review
  end

  describe Achievements::Rules::FirstListener do
    it "counts the first score of a release by someone who didn't share it, dated this week" do
      fresh = share(at: now - 1.day)
      reply(sharer, fresh, at: now - 23.hours)
      reply(olya, fresh, at: now - 20.hours)
      reply(petro, fresh, at: now - 10.hours)

      # Petro was first, last week.
      older = share(at: now - 12.days)
      reply(petro, older, at: now - 10.days)
      reply(olya, older, at: now)

      expect(counts(described_class)).to eq(olya.id => 1)
    end

    it "ignores replies that weren't scored" do
      fresh = share
      reply(petro, fresh, at: now - 20.hours, score: nil)
      reply(olya, fresh, at: now - 10.hours)

      expect(counts(described_class)).to eq(olya.id => 1)
    end
  end

  describe Achievements::Rules::Rescuer do
    it "counts a first score coming 3+ days after the share" do
      reply(olya, share(at: now - 4.days), at: now - 1.hour)
      reply(petro, share(at: now - 2.days), at: now)

      late = share(at: now - 5.days)
      reply(olya, late, at: now - 4.days)
      reply(petro, late, at: now)

      expect(counts(described_class)).to eq(olya.id => 1)
    end
  end

  describe Achievements::Rules::Lightning do
    it "counts scores within an hour of the share replied to, not under your own" do
      quick = share(at: now - 2.hours)
      reply(olya, quick, at: now - 90.minutes)
      reply(petro, quick, at: now)
      reply(sharer, quick, at: now - 119.minutes)

      expect(counts(described_class)).to eq(olya.id => 1)
    end
  end

  describe Achievements::Rules::Archaeologist do
    it "counts scores of a share more than 7 days old" do
      reply(olya, share(at: now - 8.days), at: now)
      reply(petro, share(at: now - 2.days), at: now)

      # Answering a fresh re-share of an old release isn't digging.
      release = create(:release, :resolved)
      share(release, at: now - 30.days)
      reply(petro, share(release, by: olya, at: now - 1.day), at: now)

      expect(counts(described_class)).to eq(olya.id => 1)
    end
  end

  describe Achievements::Rules::BubbleExit do
    def release(styles)
      create(:release, :resolved, styles: styles)
    end

    it "counts scores of releases with a style the member never scored before" do
      reply(olya, share(release(%w[Shoegaze])), at: now - 20.days)
      reply(olya, share(release([ "Shoegaze", "Dream Pop" ])), at: now - 1.hour)
      reply(olya, share(release(%w[Shoegaze])), at: now)
      reply(olya, share(release(nil)), at: now)
      # Someone else's taste doesn't make it old for Petro.
      reply(petro, share(release(%w[Shoegaze])), at: now)

      expect(counts(described_class)).to eq(olya.id => 1, petro.id => 1)
    end
  end

  describe Achievements::Rules::LongCritic do
    it "counts reviews of 300+ characters across all their messages" do
      fresh = share
      reply(olya, fresh, at: now - 2.hours, text: "а" * 200)
      reply(olya, fresh, at: now - 1.hour, text: "б" * 100)
      reply(petro, fresh, at: now, text: "в" * 299)

      expect(counts(described_class)).to eq(olya.id => 1)
    end
  end

  describe Achievements::Rules::Necromancer do
    it "counts different releases from before 1980 shared this week" do
      old = create(:release, :resolved, year: 1975)
      share(old, at: now - 1.day)
      share(old, at: now - 2.hours)
      share(create(:release, :resolved, year: 1979), at: now)
      share(create(:release, :resolved, year: 1980), at: now)
      share(create(:release, :resolved, year: nil), at: now)
      share(create(:release, :resolved, year: 1960), at: now - 10.days)

      expect(counts(described_class)).to eq(sharer.id => 2)
    end
  end

  describe Achievements::Rules::GenreTourist do
    it "counts different Discogs styles scored this month" do
      reply(olya, share(create(:release, :resolved, styles: %w[Shoegaze Noise])), at: now - 15.days)
      reply(olya, share(create(:release, :resolved, styles: [ "Noise", "Dream Pop" ])), at: now)
      reply(petro, share(create(:release, :resolved, styles: %w[Jazz])), at: now - 30.days)

      expect(counts(described_class)).to eq(olya.id => 3)
    end
  end

  describe Achievements::Rules::Chatterbox do
    it "counts reviews with a voice message or a video note this month" do
      fresh = share
      reply(olya, fresh, at: now - 1.hour)
      reply(olya, fresh, at: now, source: :voice)
      reply(petro, fresh, at: now, source: :video_note)
      reply(sharer, fresh, at: now)

      expect(counts(described_class)).to eq(olya.id => 1, petro.id => 1)
    end
  end
end
