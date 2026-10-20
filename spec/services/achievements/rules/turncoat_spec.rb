require "rails_helper"

RSpec.describe Achievements::Rules::Turncoat do
  subject(:rule) { described_class.new(code: "turncoat", title: "Перевзувач") }

  let(:chat) { create(:chat) }
  let(:olya) { create(:user, username: "olya") }
  let(:now) { Time.zone.local(2026, 10, 21, 12) }
  let(:week) { Achievements::Period.current(:week, now: now) }

  def change(user, at:, chat: self.chat)
    review = create(:review, chat: chat, user: user, release: create(:release, :resolved), score: 8)
    review.score_changes.create!(from_score: 5, to_score: 8, changed_at: at)
  end

  it "counts each member's score changes this week, in this chat" do
    2.times { change(olya, at: now - 1.day) }
    change(olya, at: now - 3.days) # last week
    change(olya, at: now, chat: create(:chat))
    petro = create(:user)
    change(petro, at: now)

    expect(rule.levels(chat, week)).to eq(olya.id => 2, petro.id => 1)
    expect(rule.winner_ids(chat, week)).to contain_exactly(olya.id, petro.id)
  end

  it "is secret and words its messages without a gender" do
    expect(rule).to be_secret
    expect(rule.line(:awarded, "@olya", 1)).to eq("🏆 @olya отримує ачівку «Перевзувач»: змінена оцінка цього тижня")
    expect(rule.line(:leveled, "@olya", 2)).to eq("🔄 @olya перевзувається: 2 рази цього тижня")
    expect(rule.line(:leveled, "@olya", 5)).to eq("🔄 @olya перевзувається: 5 разів цього тижня")
    expect(rule.line(:revoked, "@olya", nil)).to eq("↩️ @olya втрачає ачівку «Перевзувач»: змін оцінок цього тижня не лишилось")
  end
end
