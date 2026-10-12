require "rails_helper"

RSpec.describe ChatModeHandler do
  let(:chat) { create(:chat) }
  let(:message) { telegram_message(text: nil, voice: { file_id: "v" }).with_indifferent_access }

  it "does no database work when built" do
    expect { DefaultHandler.new(message: message, chat: chat) }.not_to change(User, :count)
  end

  it "makes the sender a chat member even when the message gets no reply" do
    allow(Response::Voice).to receive(:new).and_return(double(call: nil))

    DefaultHandler.new(message: message, chat: chat).call

    expect(chat.users.sole.telegram_id).to eq(telegram_from[:id].to_s)
  end
end
