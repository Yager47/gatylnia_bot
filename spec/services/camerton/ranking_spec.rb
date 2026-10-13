require "rails_helper"

RSpec.describe Camerton::Ranking do
  let(:chat) { create(:chat) }

  def release_scored(name, *scores, chat: self.chat, shared_at: Time.current)
    release = create(:release, :resolved, artist: "Artist", title: name)
    create(:release_share, chat: chat, release: release, shared_at: shared_at)
    scores.each { |score| create(:review, chat: chat, release: release, score: score) }
    release
  end

  def ranking(best: true, **options)
    described_class.new(chat: chat, best: best, **options).text
  end

  it "lists releases by average score, best first, ties going to more scores" do
    release_scored("Mid", 5, 6)
    release_scored("Great", 9, 10)
    release_scored("Good, few", 8, 8)
    release_scored("Good, many", 8, 8, 8)

    expect(ranking).to eq(<<~TEXT.strip)
      🏆 Топ за весь час:

      1. 🎵 Artist — Great · 9.5 (2 оцінки)
      2. 🎵 Artist — Good, many · 8 (3 оцінки)
      3. 🎵 Artist — Good, few · 8 (2 оцінки)
      4. 🎵 Artist — Mid · 5.5 (2 оцінки)
    TEXT
  end

  it "lists the worst first for дно" do
    release_scored("Great", 9, 10)
    release_scored("Bad", 1, 3)

    expect(ranking(best: false).lines.map(&:strip)).to eq(
      [ "🗑 Дно за весь час:", "", "1. 🎵 Artist — Bad · 2 (2 оцінки)", "2. 🎵 Artist — Great · 9.5 (2 оцінки)" ]
    )
  end

  it "needs two scores, ignores replies that weren't reviews and other chats" do
    release_scored("Lonely", 10)
    unscored = release_scored("Unscored", 7)
    create(:review, chat: chat, release: unscored, score: nil)
    release_scored("Elsewhere", 10, 10, chat: create(:chat))

    expect(ranking).to eq("🏆 Топ за весь час:\n\nПоки нема релізів з 2 і більше оцінками.")
  end

  it "limits a period to releases shared in it" do
    release_scored("Old", 10, 10, shared_at: 2.months.ago)
    release_scored("New", 6, 7)

    expect(ranking(range: Time.current.all_month, label: "поточний місяць")).to eq(
      "🏆 Топ за поточний місяць:\n\n1. 🎵 Artist — New · 6.5 (2 оцінки)"
    )
  end

  it "shows ten releases at most" do
    11.times { |index| release_scored("Song #{index}", 7, 7) }

    expect(ranking.lines.count { |line| line.match?(/\A\d+\. /) }).to eq(10)
  end

  it "runs the same number of queries however many releases are scored" do
    release_scored("One", 7, 8)
    queries_for_one = count_queries { ranking }

    5.times { |index| release_scored("More #{index}", 6, 9) }

    expect(count_queries { ranking }).to eq(queries_for_one)
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
