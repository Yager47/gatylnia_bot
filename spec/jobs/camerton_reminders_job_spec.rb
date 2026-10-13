require "rails_helper"
require "fugit"

RSpec.describe CamertonRemindersJob do
  it "enqueues one digest per chat with Camerton on" do
    on = create_list(:chat, 2, camerton_enabled: true)
    create(:chat, camerton_enabled: false)

    described_class.perform_now

    on.each { |chat| expect(SendCamertonDigestJob).to have_been_enqueued.with(chat) }
    expect(SendCamertonDigestJob).to have_been_enqueued.exactly(2).times
  end

  # Heroku and CI run with a UTC system clock, where a schedule without a
  # zone means UTC. Force that here so the spec doesn't depend on the
  # developer machine's time zone.
  it "runs every day at 09:00 Kyiv time in production, on a UTC server" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "camerton_reminders")
    expect(task.fetch("class")).to eq("CamertonRemindersJob")

    with_system_time_zone("UTC") do
      schedule = Fugit.parse(task.fetch("schedule"))

      [ Time.utc(2026, 7, 1, 12), Time.utc(2026, 12, 1, 12) ].each do |from| # summer and winter time
        expect(schedule.next_time(from).to_t.in_time_zone("Europe/Kyiv").strftime("%H:%M")).to eq("09:00")
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

RSpec.describe SendCamertonDigestJob do
  let(:chat) { create(:chat, camerton_enabled: true) }

  it "delivers the chat's digest" do
    digest = instance_double(Camerton::ReminderDigest, deliver: nil)
    allow(Camerton::ReminderDigest).to receive(:new).with(chat).and_return(digest)

    described_class.perform_now(chat)

    expect(digest).to have_received(:deliver)
  end

  it "retries when Telegram is unreachable" do
    allow_any_instance_of(Camerton::ReminderDigest).to receive(:deliver).and_raise(Faraday::ConnectionFailed, "down")

    described_class.perform_now(chat)

    expect(described_class).to have_been_enqueued.with(chat)
  end
end
