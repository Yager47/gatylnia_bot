require "rails_helper"

RSpec.describe CheckAchievementsJob do
  let(:chat) { create(:chat, camerton_enabled: true) }

  it "checks the chat's achievements and streaks" do
    checker = instance_double(Achievements::Checker, call: nil)
    streaks = instance_double(Achievements::Streaks, call: nil)
    allow(Achievements::Checker).to receive(:new).with(chat).and_return(checker)
    allow(Achievements::Streaks).to receive(:new).with(chat).and_return(streaks)

    described_class.perform_now(chat)

    expect(checker).to have_received(:call)
    expect(streaks).to have_received(:call)
  end

  it "retries when Telegram is unreachable" do
    allow_any_instance_of(Achievements::Checker).to receive(:call).and_raise(Faraday::ConnectionFailed, "down")

    described_class.perform_now(chat)

    expect(described_class).to have_been_enqueued.with(chat)
  end
end

RSpec.describe CheckAllAchievementsJob do
  it "checks every chat with Camerton on" do
    on = create(:chat, camerton_enabled: true)
    create(:chat, camerton_enabled: false)

    described_class.perform_now

    expect(CheckAchievementsJob).to have_been_enqueued.with(on).exactly(:once)
    expect(CheckAchievementsJob).to have_been_enqueued.exactly(:once)
  end

  it "runs every day at 09:00 Kyiv time" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "check_achievements")

    expect(task).to eq("class" => "CheckAllAchievementsJob", "schedule" => "0 9 * * * Europe/Kyiv")
  end
end
