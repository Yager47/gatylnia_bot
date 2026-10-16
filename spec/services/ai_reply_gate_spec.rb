require "rails_helper"

RSpec.describe AiReplyGate do
  let(:chat) { create(:chat) }
  let(:person_message) { create(:message, chat: chat, content: "Покакав") }
  let(:bot_message) { create(:message, chat: chat, role: :assistant, user: nil, content: "Gattuso забиває мʼяч!") }

  def message(content: "а чим зірвав?", **attrs)
    create(:message, chat: chat, content: content, **attrs)
  end

  def decision(**attrs)
    described_class.new(message(**attrs)).decision
  end

  it "always answers a mention of the bot, in any case" do
    expect(decision(content: "@Test_Bot ти тут?")).to eq(:always)
  end

  it "always answers a reply to the bot" do
    expect(decision(content: "сам ти мʼяч", reply_to: bot_message)).to eq(:always)
  end

  it "never joins a reply to someone else" do
    expect(decision(reply_to: person_message)).to eq(:never)
  end

  it "never joins a reply to a message it didn't record" do
    expect(decision(reply_snapshot: { "user_name" => "Artem", "content" => "старе" })).to eq(:never)
  end

  it "answers a reply to someone else when it mentions the bot" do
    expect(decision(content: "@test_bot скажи йому", reply_to: person_message)).to eq(:always)
  end

  it "leaves a message to no one in particular to chance" do
    expect(decision).to eq(:maybe)
  end

  describe "#answer?" do
    it "answers a :maybe message only when the roll is under the chance" do
      gate = described_class.new(message)

      expect(gate.answer?(0.59)).to be(true)
      expect(gate.answer?(0.6)).to be(false)
    end

    it "ignores the roll otherwise" do
      expect(described_class.new(message(content: "@test_bot ало")).answer?(0.99)).to be(true)
      expect(described_class.new(message(reply_to: person_message)).answer?(0.0)).to be(false)
    end
  end
end
