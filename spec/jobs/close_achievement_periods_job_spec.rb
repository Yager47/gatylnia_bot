require "rails_helper"
require "fugit"

RSpec.describe CloseAchievementPeriodsJob do
  it "enqueues one close per chat with Camerton on" do
    on = create_list(:chat, 2, camerton_enabled: true)
    create(:chat, camerton_enabled: false)

    described_class.perform_now("week")

    on.each { |chat| expect(CloseChatAchievementsJob).to have_been_enqueued.with(chat, "week") }
    expect(CloseChatAchievementsJob).to have_been_enqueued.exactly(2).times
  end

  # As for the reminders: Heroku's clock is UTC, so the zone must be in the
  # schedule itself.
  it "decides week-old releases daily at 09:00 Kyiv time on a UTC server" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "close_release_achievements")
    expect(task.values_at("class", "args")).to eq([ "CloseAchievementPeriodsJob", [ "release" ] ])

    with_system_time_zone("UTC") do
      schedule = Fugit.parse(task.fetch("schedule"))
      [ Time.utc(2026, 7, 15, 12), Time.utc(2026, 12, 15, 12) ].each do |from|
        next_run = schedule.next_time(from).to_t.in_time_zone("Europe/Kyiv")
        expect([ next_run.strftime("%H:%M"), next_run.to_date ]).to eq([ "09:00", from.to_date + 1 ])
      end
    end
  end

  it "closes weeks on Mondays and months on the 1st, at 09:00 Kyiv time on a UTC server" do
    tasks = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production")

    with_system_time_zone("UTC") do
      { "close_weekly_achievements" => [ "week", "Monday" ], "close_monthly_achievements" => [ "month", "01" ] }.each do |name, (kind, day)|
        task = tasks.fetch(name)
        expect(task.fetch("class")).to eq("CloseAchievementPeriodsJob")
        expect(task.fetch("args")).to eq([ kind ])

        [ Time.utc(2026, 7, 15, 12), Time.utc(2026, 12, 15, 12) ].each do |from| # summer and winter time
          next_run = Fugit.parse(task.fetch("schedule")).next_time(from).to_t.in_time_zone("Europe/Kyiv")
          expect(next_run.strftime("%H:%M")).to eq("09:00")
          expect(next_run.strftime(kind == "week" ? "%A" : "%d")).to eq(day)
        end
      end
    end
  end

  def with_system_time_zone(zone)
    original = ENV["TZ"]
    ENV["TZ"] = zone
    yield
  ensure
    ENV["TZ"] = original
  end
end

RSpec.describe CloseChatAchievementsJob do
  let(:chat) { create(:chat, camerton_enabled: true) }

  it "closes the chat's period of that kind" do
    closer = instance_double(Achievements::Closer, call: nil)
    allow(Achievements::Closer).to receive(:new).with(chat, :month).and_return(closer)

    described_class.perform_now(chat, "month")

    expect(closer).to have_received(:call)
  end

  it "retries when Telegram is unreachable" do
    allow_any_instance_of(Achievements::Closer).to receive(:call).and_raise(Faraday::ConnectionFailed, "down")

    described_class.perform_now(chat, "week")

    expect(described_class).to have_been_enqueued.with(chat, "week")
  end
end
