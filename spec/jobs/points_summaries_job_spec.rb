require "rails_helper"
require "fugit"

RSpec.describe PointsSummariesJob do
  it "enqueues one summary per default or accountant chat" do
    default = create(:chat, mode: :default)
    accountant = create(:chat, mode: :accountant)
    create(:chat, mode: :quiet)

    described_class.perform_now

    [ default, accountant ].each { |chat| expect(SendPointsSummaryJob).to have_been_enqueued.with(chat) }
    expect(SendPointsSummaryJob).to have_been_enqueued.exactly(2).times
  end

  it "runs on Mondays at 10:00 Kyiv time in production, on a UTC server" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "points_summaries")
    expect(task.fetch("class")).to eq("PointsSummariesJob")

    with_system_time_zone("UTC") do
      schedule = Fugit.parse(task.fetch("schedule"))

      [ Time.utc(2026, 7, 1, 12), Time.utc(2026, 12, 1, 12) ].each do |from| # summer and winter time
        expect(schedule.next_time(from).to_t.in_time_zone("Europe/Kyiv").strftime("%A %H:%M")).to eq("Monday 10:00")
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

RSpec.describe SendPointsSummaryJob do
  it "delivers the chat's summary" do
    chat = create(:chat)
    summary = instance_double(Zhmykhcoins::WeeklySummary, deliver: nil)
    allow(Zhmykhcoins::WeeklySummary).to receive(:new).with(chat).and_return(summary)

    described_class.perform_now(chat)

    expect(summary).to have_received(:deliver)
  end
end
