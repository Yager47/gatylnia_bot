require "rails_helper"

RSpec.describe Achievements::Rules::Streak do
  subject(:rule) { described_class.new(code: "streak", title: "Серія") }

  it "has milestones at 3, 7, 10 and every 5 days after" do
    expect((1..31).select { |days| rule.milestone?(days) }).to eq([ 3, 7, 10, 15, 20, 25, 30 ])
  end

  it "is decided by the streaks service and counts days in Ukrainian" do
    expect(rule.decided_by).to eq(:streaks)
    expect([ 1, 3, 5, 21 ].map { |days| rule.days(days) }).to eq([ "1 день", "3 дні", "5 днів", "21 день" ])
  end
end
