require "rails_helper"

RSpec.describe MessageHandler do
  let(:message) do
    { chat: { id: -100, type: "supergroup", title: "Гатильня" }, from: { id: 555 }, text: "Ало" }.with_indifferent_access
  end
  let(:mode_handler) { instance_double(DefaultHandler, call: nil) }

  before { allow(DefaultHandler).to receive(:new).and_return(mode_handler) }

  it "creates a chat seen for the first time" do
    described_class.new(message).call

    expect(Chat.sole).to have_attributes(telegram_id: "-100", telegram_type: "supergroup", title: "Гатильня")
  end

  # Simulates another job inserting the chat between our find_by and INSERT.
  it "uses the existing chat when it was created concurrently" do
    existing = create(:chat, telegram_id: "-100")
    allow(Chat).to receive(:find_by).and_return(nil)

    described_class.new(message).call

    expect(Chat.count).to eq(1)
    expect(DefaultHandler).to have_received(:new).with(message: message, chat: existing)
  end
end
