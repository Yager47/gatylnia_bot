require "rails_helper"

RSpec.describe Achievements::Period do
  it "is a Monday-to-Sunday week in Kyiv time, keyed by ISO week" do
    # Sunday 22:30 UTC is already Monday in Kyiv (UTC+3 in summer time).
    period = described_class.current(:week, now: Time.utc(2026, 10, 18, 22, 30))

    expect(period.key).to eq("2026-W43")
    expect(period.range.begin).to eq(Time.zone.local(2026, 10, 19))
    expect(period.range.end).to eq(Time.zone.local(2026, 10, 25).end_of_day)
  end

  it "uses the ISO year for a week that starts in December" do
    expect(described_class.current(:week, now: Time.zone.local(2027, 1, 1, 12)).key).to eq("2026-W53")
  end

  it "is a calendar month in Kyiv time" do
    period = described_class.current(:month, now: Time.utc(2026, 10, 31, 22, 30))

    expect(period.key).to eq("2026-11")
    expect(period.range).to eq(Time.zone.local(2026, 11, 1)..Time.zone.local(2026, 11, 30).end_of_day)
  end

  it "rejects other kinds" do
    expect { described_class.current(:year) }.to raise_error(ArgumentError)
  end
end
