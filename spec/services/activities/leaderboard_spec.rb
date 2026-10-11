require "rails_helper"

RSpec.describe Activities::Leaderboard do
  let(:chat) { create(:chat) }
  let(:week) { Time.current.all_week }

  def leaderboard(kind: :coffee, range: week)
    described_class.new(chat: chat, kind: kind, range: range).rows.map { |row| [ row.user.name, row.total ] }
  end

  it "sums amounts per user, highest first" do
    olha = create(:user, first_name: "Ольга", last_name: nil)
    petro = create(:user, first_name: "Петро", last_name: nil)
    create(:activity, chat: chat, user: olha)
    create(:activity, chat: chat, user: petro, amount: 2)
    create(:activity, chat: chat, user: petro)

    expect(leaderboard).to eq([ [ "Петро", 3 ], [ "Ольга", 1 ] ])
  end

  it "orders equal totals by name" do
    create(:activity, chat: chat, user: create(:user, first_name: "Ярема", last_name: nil))
    create(:activity, chat: chat, user: create(:user, first_name: "Андрій", last_name: nil))

    expect(leaderboard.map(&:first)).to eq(%w[Андрій Ярема])
  end

  it "counts only the requested kind, chat and period" do
    user = create(:user, first_name: "Іван", last_name: nil)
    create(:activity, chat: chat, user: user)
    create(:activity, :push_ups, chat: chat, user: user)
    create(:activity, chat: create(:chat), user: user)
    create(:activity, chat: chat, user: user, occurred_at: 2.weeks.ago)

    expect(leaderboard).to eq([ [ "Іван", 1 ] ])
    expect(leaderboard(kind: :push_ups)).to eq([ [ "Іван", 1 ] ])
  end

  it "uses the message time, not when the row was written" do
    user = create(:user)
    create(:activity, chat: chat, user: user, occurred_at: 2.weeks.ago, created_at: Time.current)

    expect(leaderboard).to be_empty
  end

  it "is empty when nobody has activities in the period" do
    expect(leaderboard).to eq([])
  end
end
