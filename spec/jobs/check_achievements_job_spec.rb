require "rails_helper"

RSpec.describe CheckAchievementsJob do
  let(:chat) { create(:chat, camerton_enabled: true) }

  it "checks the chat's achievements" do
    checker = instance_double(Achievements::Checker, call: nil)
    allow(Achievements::Checker).to receive(:new).with(chat).and_return(checker)

    described_class.perform_now(chat)

    expect(checker).to have_received(:call)
  end

  it "retries when Telegram is unreachable" do
    allow_any_instance_of(Achievements::Checker).to receive(:call).and_raise(Faraday::ConnectionFailed, "down")

    described_class.perform_now(chat)

    expect(described_class).to have_been_enqueued.with(chat)
  end
end
