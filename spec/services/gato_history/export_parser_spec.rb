require "rails_helper"

RSpec.describe GatoHistory::ExportParser do
  let(:messages) { described_class.new(file_fixture("chat_export")).each_message.to_a }

  it "reads every file in numeric order, skipping service messages" do
    expect(messages.map(&:telegram_message_id)).to eq([ 100, 101, 102, 200, 300 ])
  end

  it "takes the sender's Telegram id from their userpic" do
    expect(messages.first).to have_attributes(sender_id: "555", sender_name: "Петро Тест", text: "Погатив")
  end

  it "gives joined messages the previous sender, also across files" do
    expect(messages[1]).to have_attributes(sender_id: "555", sender_name: "Петро Тест")
    expect(messages[3]).to have_attributes(sender_id: nil, sender_name: "Гатильня")
  end

  it "leaves the id empty for a sender without a userpic" do
    expect(messages[2]).to have_attributes(sender_id: nil, sender_name: "Гатильня", text: nil)
  end

  it "turns links into their text and <br> into newlines" do
    expect(messages[1].text).to eq("@GatylniaBot рядок\nдругий")
  end

  it "parses the Ukrainian dates in Kyiv time" do
    expect(messages.first.sent_at).to eq(Time.zone.local(2026, 4, 11, 10, 42, 17))
    expect(messages.first.sent_at.utc_offset).to eq(3.hours)
    expect(messages[3].sent_at).to eq(Time.zone.local(2026, 7, 2, 23, 59, 59))
  end

  it "fails loudly on a directory without an export" do
    expect { described_class.new(file_fixture("chat_export").join("photos")).each_message.first }
      .to raise_error(ArgumentError, /No messages/)
  end
end
