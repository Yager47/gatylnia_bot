require "rails_helper"

# The rules decided at the end of a period, on 2026-W43 (Monday 19 to
# Sunday 25 October) and October 2026.
RSpec.describe "Achievements::Rules decided at the end of a period" do
  let(:chat) { create(:chat) }
  let(:now) { Time.zone.local(2026, 10, 21, 12) }
  let(:olya) { create(:user) }
  let(:petro) { create(:user) }
  let(:ivan) { create(:user) }

  def winners(rule)
    rule.winner_ids(chat, Achievements::Period.current(rule.period_kind, now: now))
  end

  def share(by:, kind: :song, at: now - 1.day)
    release = create(:release, *(kind == :album ? [ :album ] : [ :resolved ]))
    create(:release_share, chat: chat, release: release, user: by, shared_at: at)
  end

  def score(user, release_or_share, score, at: now)
    release = release_or_share.is_a?(ReleaseShare) ? release_or_share.release : release_or_share
    review = create(:review, chat: chat, release: release, user: user, score: score)
    create(:review_message, review: review, sent_at: at,
      release_share: release_or_share.is_a?(ReleaseShare) ? release_or_share : create(:release_share, chat: chat, release: release, shared_at: at - 40.days))
    review
  end

  describe Achievements::Rules::SharerTitle do
    let(:best) { described_class.new(code: "best", title: "Найшанованіший", worst: false) }
    let(:worst) { described_class.new(code: "worst", title: "Найзневаженіший", worst: true) }

    it "ranks sharers of 2+ releases this week by the average of every score, theirs included" do
      olyas = [ share(by: olya), share(by: olya) ]
      score(petro, olyas[0], 9)
      score(olya, olyas[1], 7) # 8 on average
      petros = [ share(by: petro), share(by: petro), share(by: petro, at: now - 10.days) ]
      score(olya, petros[0], 3)
      score(ivan, petros[1], 5)
      score(olya, petros[2], 10) # last week's share
      score(petro, share(by: ivan), 1) # Ivan shared only one

      expect(winners(best)).to eq([ olya.id ])
      expect(winners(worst)).to eq([ petro.id ])
    end

    it "lets tied sharers share the title, and needs scores" do
      [ olya, petro ].each { |sharer| 2.times { score(ivan, share(by: sharer), 6) } }
      2.times { share(by: ivan) }

      expect(winners(best)).to contain_exactly(olya.id, petro.id)
    end

    it "words both" do
      expect(best.description).to eq("найвища середня оцінка релізів, скинутих за тиждень (від 2)")
      expect(worst.description).to start_with("найнижча")
    end
  end

  describe Achievements::Rules::Eater do
    let(:songs) { described_class.new(code: "s", title: "Пісенний Пожирач", kinds: %w[song]) }
    let(:albums) { described_class.new(code: "a", title: "Альбомний Пожирач", kinds: %w[album]) }
    let(:both) { described_class.new(code: "b", title: "Пожирач", kinds: %w[album song]) }

    it "goes to whoever scored every song or album shared this week, own shares included, and Пожирач to both" do
      week_songs = [ share(by: olya), share(by: petro) ]
      week_albums = [ share(by: petro, kind: :album), share(by: ivan, kind: :album) ]
      share(by: ivan, at: now - 10.days) # last week's

      (week_songs + week_albums).each { |s| score(olya, s, 7) }
      week_songs.each { |s| score(petro, s, 7) }
      week_albums.each { |s| score(ivan, s, 7) }

      expect(winners(both)).to eq([ olya.id ])
      expect(winners(songs)).to eq([ petro.id ])
      expect(winners(albums)).to eq([ ivan.id ])
    end

    it "needs at least 2 of the kind shared, and every one scored" do
      only = share(by: olya, kind: :album)
      score(petro, only, 8)
      week_songs = [ share(by: olya), share(by: olya) ]
      score(petro, week_songs[0], 8)
      create(:review, chat: chat, release: week_songs[1].release, user: petro, score: nil)

      expect(winners(albums)).to be_empty
      expect(winners(songs)).to be_empty
    end

    it "words each" do
      expect(both.description).to eq("оцінені усі пісні й альбоми, скинуті за тиждень (від 2)")
      expect(songs.description).to include("усі пісні,")
      expect(albums.description).to include("усі альбоми,")
    end
  end

  describe Achievements::Rules::AllPositive do
    subject(:rule) { described_class.new(code: "x", title: "Всеїдний") }

    it "needs 3+ scores this week, all 8–10" do
      [ 8, 9, 10 ].each { |value| score(olya, create(:release, :resolved), value) }
      [ 8, 9, 10, 7 ].each { |value| score(petro, create(:release, :resolved), value) }
      [ 9, 9 ].each { |value| score(ivan, create(:release, :resolved), value) }

      expect(winners(rule)).to eq([ olya.id ])
    end
  end

  describe Achievements::Rules::Grumbler do
    subject(:rule) { described_class.new(code: "x", title: "Буркотун", secret: true) }

    it "goes to the most 1–3 scores this month" do
      [ 1, 3, 4 ].each { |value| score(olya, create(:release, :resolved), value) }
      [ 2 ].each { |value| score(petro, create(:release, :resolved), value) }
      [ 1, 1, 1 ].each { |value| score(ivan, create(:release, :resolved), value, at: now - 30.days) }

      expect(winners(rule)).to eq([ olya.id ])
      expect(rule).to be_secret
    end
  end

  describe Achievements::Rules::Contrarian do
    subject(:rule) { described_class.new(code: "x", title: "Не такий як всі", secret: true) }

    # Each release scored by the member and two others.
    def releases(user, own, others, count: 8, at: now)
      count.times do
        release = create(:release, :resolved)
        score(user, release, own, at: at)
        others.each { |other_score| score(create(:user), release, other_score, at: at - 50.days) }
      end
    end

    it "goes to the biggest average gap from the others' average, over 8+ releases" do
      releases(olya, 10, [ 2, 4 ]) # gap 7
      releases(petro, 3, [ 8, 8 ]) # gap 5
      releases(ivan, 1, [ 10, 10 ], count: 7) # too few

      expect(winners(rule)).to eq([ olya.id ])
    end

    it "leaves out releases with fewer than 2 other scores" do
      releases(olya, 10, [ 1 ])

      expect(winners(rule)).to be_empty
    end
  end
end
