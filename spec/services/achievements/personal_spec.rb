require "rails_helper"

RSpec.describe Achievements::Personal do
  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:olya) { create(:user, first_name: "Оля", last_name: nil, chats: [ chat ]) }
  let(:now) { Time.zone.local(2026, 10, 20, 12) }

  def rule(code, period_kind: :month, goal: nil, counts: {}, secret: false)
    Struct.new(:code, :period_kind, :goal, :progress, :secret) do
      def title = "Ачівка #{code}"
      def secret? = secret
      def counts(_chat, _period) = progress
    end.new(code, period_kind, goal, counts, secret)
  end

  def text(rules)
    described_class.new(chat: chat, user: olya, rules: rules, now: now).text
  end

  def earn(code, period:, user: olya, revoked: false)
    create(:achievement, chat: chat, user: user, code: code, period: period, revoked_at: (now if revoked))
  end

  it "shows what's held this period, progress towards the rest, and all-time totals" do
    earn("half", period: "2026-10")
    earn("half", period: "2026-09")
    earn("full", period: "2026-08")
    earn("week", period: "2026-W43")

    rules = [
      rule("half", goal: 21, counts: { olya.id => 25 }),
      rule("full", goal: 42, counts: { olya.id => 25 }),
      rule("week", period_kind: :week, goal: 5),
      rule("weekly_other", period_kind: :week, goal: 3)
    ]

    expect(text(rules)).to eq(<<~TEXT.chomp)
      🏆 Ачівки: Оля

      Цього місяця:
      ✅ Ачівка half
      ⏳ Ачівка full — 25/42

      Цього тижня:
      ✅ Ачівка week
      ⏳ Ачівка weekly_other — 0/3

      Усього: Ачівка half ×2, Ачівка full ×1, Ачівка week ×1
    TEXT
  end

  it "leaves out revoked and other members' achievements, unearned secrets and rules with no goal" do
    earn("half", period: "2026-10", revoked: true)
    earn("half", period: "2026-10", user: create(:user, chats: [ chat ]))

    rules = [ rule("half", goal: 21), rule("secret", goal: 1, secret: true), rule("title") ]

    expect(text(rules)).to eq(<<~TEXT.chomp)
      🏆 Ачівки: Оля

      Цього місяця:
      ⏳ Ачівка half — 0/21

      Ще жодної ачівки — все попереду.
    TEXT
  end

  it "shows the level of an achievement that has one" do
    create(:achievement, chat: chat, user: olya, code: "grows", period: "2026-W43", level: 2)

    expect(text([ rule("grows", period_kind: :week) ])).to include("✅ Ачівка grows (2)")
  end

  it "lists per-release achievements only in the totals" do
    earn("split", period: "release-1")

    expect(text([ rule("split", period_kind: :release) ])).to eq("🏆 Ачівки: Оля\n\nУсього: Ачівка split ×1")
  end

  it "shows an earned secret" do
    earn("secret", period: "2026-10")

    expect(text([ rule("secret", goal: 1, secret: true) ])).to include("✅ Ачівка secret", "Усього: Ачівка secret ×1")
  end

  it "counts real songs for the marathons" do
    review = create(:review, chat: chat, user: olya, release: create(:release, :resolved), score: 8)
    create(:review_message, review: review, sent_at: now - 1.day)

    expect(described_class.new(chat: chat, user: olya, now: now).text).to include("⏳ Пісенний Напівмарафонець — 1/21", "⏳ Пісенний Марафонець — 1/42")
  end
end
