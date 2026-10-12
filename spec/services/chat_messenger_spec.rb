require "rails_helper"

RSpec.describe ChatMessenger do
  let(:chat) { create(:chat) }

  it "sends the message and stores Telegram's message id on it" do
    message = chat.messages.create!(role: :assistant, content: "Ало")

    described_class.new(chat: chat).deliver(message)

    expect(fake_telegram.sent_messages).to eq([ { chat_id: chat.telegram_id, text: "Ало" } ])
    expect(message.reload.telegram_message_id).to eq(1001)
  end

  it "replies in a thread when given a message to answer" do
    message = chat.messages.create!(role: :assistant, content: "Ало")

    described_class.new(chat: chat).deliver(message, reply_to: 42)

    expect(fake_telegram.sent_messages.sole[:reply_parameters].to_h).to eq(message_id: 42, allow_sending_without_reply: true)
  end

  it "sends nothing for a blank message" do
    described_class.new(chat: chat).deliver(chat.messages.build(role: :assistant, content: ""))

    expect(fake_telegram.sent_messages).to be_empty
  end
end
