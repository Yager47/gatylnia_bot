require "rails_helper"

RSpec.describe Activities::Confirmation do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, first_name: "Петро", last_name: nil) }
  let(:day) { Time.zone.local(2026, 10, 12, 9, 0) }

  def text(recorded)
    described_class.new(user: user, chat: chat, day: day).text(recorded)
  end

  it "shows the day's total for one kind, one emoji per cup just recorded" do
    create(:activity, chat: chat, user: user, occurred_at: day - 2.hours)
    create(:activity, chat: chat, user: user, occurred_at: day, amount: 2)

    expect(text(coffee: 2)).to eq("☕☕ Петро: 3 за сьогодні")
  end

  it "names each kind when several were recorded" do
    create(:activity, chat: chat, user: user, occurred_at: day)
    create(:activity, :push_ups, chat: chat, user: user, occurred_at: day)

    expect(text(coffee: 1, push_ups: 1)).to eq("☕💪 Петро: 1 кава, 1 підхід відтискань за сьогодні")
  end

  it "uses the Ukrainian plural for cups" do
    labels = [ 1, 2, 4, 5, 11, 12, 14, 20, 21, 22, 25, 111, 112 ].index_with { |count| described_class.new(user: user, chat: chat, day: day).send(:plural, count, "кава", "кави", "кав") }

    expect(labels).to eq(
      1 => "кава", 2 => "кави", 4 => "кави", 5 => "кав", 11 => "кав", 12 => "кав", 14 => "кав",
      20 => "кав", 21 => "кава", 22 => "кави", 25 => "кав", 111 => "кав", 112 => "кав"
    )
  end

  it "says кави for two cups" do
    create(:activity, chat: chat, user: user, occurred_at: day - 2.hours)
    create(:activity, chat: chat, user: user, occurred_at: day)
    create(:activity, :push_ups, chat: chat, user: user, occurred_at: day)

    expect(text(coffee: 1, push_ups: 1)).to eq("☕💪 Петро: 2 кави, 1 підхід відтискань за сьогодні")
  end

  it "counts only that user, chat and day" do
    create(:activity, :push_ups, chat: chat, user: user, occurred_at: day)
    create(:activity, :push_ups, chat: chat, user: user, occurred_at: day - 1.day)
    create(:activity, :push_ups, chat: create(:chat), user: user, occurred_at: day)
    create(:activity, :push_ups, chat: chat, occurred_at: day)

    expect(text(push_ups: 1)).to eq("💪 Петро: 1 підхід за сьогодні")
  end

  it "uses the plural for push-up sets in the combined message" do
    create(:activity, chat: chat, user: user, occurred_at: day)
    create_list(:activity, 2, :push_ups, chat: chat, user: user, occurred_at: day)

    expect(text(coffee: 1, push_ups: 1)).to eq("☕💪 Петро: 1 кава, 2 підходи відтискань за сьогодні")
  end

  it "uses the plural for several push-up sets" do
    create_list(:activity, 2, :push_ups, chat: chat, user: user, occurred_at: day)

    expect(text(push_ups: 1)).to eq("💪 Петро: 2 підходи за сьогодні")
  end
end
