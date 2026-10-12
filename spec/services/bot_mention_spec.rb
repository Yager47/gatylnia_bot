require "rails_helper"

RSpec.describe BotMention do
  around do |example|
    described_class.instance_variable_set(:@text, nil)
    example.run
  ensure
    described_class.instance_variable_set(:@text, nil)
  end

  it "is the lowercased bot username with an @" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("BOT_USERNAME").and_return("Test_Bot")

    expect(described_class.text).to eq("@test_bot")
  end

  it "raises instead of falling back to a bare @ when BOT_USERNAME is missing" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("BOT_USERNAME").and_raise(KeyError)

    expect { described_class.text }.to raise_error(KeyError)
  end
end
