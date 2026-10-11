require "rails_helper"

RSpec.describe TelegramUpdates::Command do
  def parse(text, entities: [ { type: "bot_command", offset: 0, length: text[%r{\A\S+}].to_s.length } ])
    described_class.parse({ text: text, entities: entities }.with_indifferent_access, bot_username: "test_bot")
  end

  it "parses a bare command" do
    expect(parse("/ping")).to eq("ping")
  end

  it "parses a command addressed to this bot, ignoring case in the bot name" do
    expect(parse("/ping@test_bot")).to eq("ping")
    expect(parse("/PING@Test_Bot")).to eq("ping")
  end

  it "ignores arguments after the command" do
    expect(parse("/ping з аргументами")).to eq("ping")
  end

  it "returns unknown command names for the caller to look up" do
    expect(parse("/pingx")).to eq("pingx")
  end

  it "ignores a command addressed to another bot" do
    expect(parse("/ping@other_bot")).to be_nil
  end

  it "ignores text without a bot_command entity" do
    expect(parse("/ping", entities: [])).to be_nil
  end

  it "ignores a command that isn't at the start of the message" do
    expect(parse("скажи /ping", entities: [ { type: "bot_command", offset: 6, length: 5 } ])).to be_nil
  end

  it "ignores other entity types at offset 0" do
    expect(parse("/ping", entities: [ { type: "bold", offset: 0, length: 5 } ])).to be_nil
  end

  it "handles a message without text" do
    expect(described_class.parse({ entities: [ { type: "bot_command", offset: 0, length: 5 } ] }.with_indifferent_access, bot_username: "test_bot")).to be_nil
  end
end
