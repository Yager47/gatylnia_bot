require "rails_helper"

RSpec.describe Activities::Reward do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, chats: [ chat ]) }
  let(:morning) { Time.zone.local(2026, 10, 22, 8, 0) }

  # Records the activities one after another, like the jobs do, and returns
  # each one's reward amount (nil when it earned nothing).
  def rewards(kind, count, from: morning)
    Array.new(count) do |index|
      activity = create(:activity, kind, user: user, chat: chat, occurred_at: from + index.minutes)
      described_class.new(activity).grant&.amount
    end
  end

  it "pays 25 for the first cup, 10 for the second, nothing for the third and takes 25 from the fourth on" do
    expect(rewards(:coffee, 5)).to eq([ 25, 10, nil, -25, -25 ])
    expect(Point.count).to eq(4)
  end

  it "pays 100 for each of the first three push-up sets a day, then nothing" do
    expect(rewards(:push_ups, 4)).to eq([ 100, 100, 100, nil ])
    expect(Point.count).to eq(3)
  end

  it "links the point to the activity, with a reason" do
    activity = create(:activity, :coffee, user: user, chat: chat, occurred_at: morning)
    point = described_class.new(activity).grant

    expect(point).to have_attributes(user: user, chat: chat, activity: activity, giver: nil, reason: "Кава №1")
  end

  it "starts counting again at Kyiv midnight" do
    expect(rewards(:coffee, 5, from: Time.zone.local(2026, 10, 22, 23, 57))).to eq([ 25, 10, nil, 25, 10 ])
  end

  it "counts each user and chat apart" do
    rewards(:coffee, 4)
    other = create(:activity, :coffee, chat: chat, occurred_at: morning + 1.hour)
    elsewhere = create(:activity, :coffee, user: user, chat: create(:chat), occurred_at: morning + 1.hour)

    expect(described_class.new(other).grant.amount).to eq(25)
    expect(described_class.new(elsewhere).grant.amount).to eq(25)
  end

  it "doesn't count a later coffee when a late retry records an earlier one" do
    create(:activity, :coffee, user: user, chat: chat, occurred_at: morning + 1.hour)
    earlier = create(:activity, :coffee, user: user, chat: chat, occurred_at: morning)

    expect(described_class.new(earlier).grant.reason).to eq("Кава №1")
  end

  it "is taken away with the activity" do
    activity = create(:activity, :coffee, user: user, chat: chat, occurred_at: morning)
    described_class.new(activity).grant

    expect { activity.destroy! }.to change(Point, :count).from(1).to(0)
  end
end
