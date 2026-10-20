require "rails_helper"

RSpec.describe Achievements::Rules::SongMarathon do
  subject(:rule) { described_class.new(code: "test_marathon", title: "Тест", goal: 2) }

  let(:chat) { create(:chat) }
  let(:user) { create(:user) }
  let(:period) { Achievements::Period.current(:month, now: Time.zone.local(2026, 10, 20, 12)) }

  def scored(user, first_sent_at:, score: 7, kind: :song, chat: self.chat)
    release = create(:release, kind == :album ? :album : :resolved)
    review = create(:review, chat: chat, release: release, user: user, score: score)
    create(:review_message, review: review, sent_at: first_sent_at)
    create(:review_message, review: review, sent_at: first_sent_at + 40.days)
    review
  end

  it "describes the goal in Ukrainian" do
    expect(described_class.new(code: "x", title: "x", goal: 21).description).to eq("21 оцінена пісня за місяць")
    expect(described_class.new(code: "x", title: "x", goal: 42).description).to eq("42 оцінені пісні за місяць")
  end

  it "picks members with enough songs scored this month, dated by the first message" do
    other = create(:user)
    2.times { scored(user, first_sent_at: Time.zone.local(2026, 10, 1)) }
    scored(other, first_sent_at: Time.zone.local(2026, 10, 31, 23, 59))
    # A later message in this month doesn't bring last month's review in.
    scored(other, first_sent_at: Time.zone.local(2026, 9, 30, 23, 59))

    expect(rule.winner_ids(chat, period)).to eq([ user.id ])
  end

  it "doesn't count albums, unscored reviews, reviews without messages or other chats" do
    scored(user, first_sent_at: Time.zone.local(2026, 10, 2))
    scored(user, first_sent_at: Time.zone.local(2026, 10, 2), kind: :album)
    scored(user, first_sent_at: Time.zone.local(2026, 10, 2), score: nil)
    scored(user, first_sent_at: Time.zone.local(2026, 10, 2), chat: create(:chat))
    create(:review, chat: chat, user: user, release: create(:release, :resolved), score: 9, source: :spreadsheet)

    expect(rule.winner_ids(chat, period)).to be_empty
  end
end
