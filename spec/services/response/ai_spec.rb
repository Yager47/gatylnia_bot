require "rails_helper"

RSpec.describe Response::Ai do
  let(:chat) { create(:chat) }
  let(:trigger) { create(:message, chat: chat, content: "а чим зірвав?", telegram_message_id: 10) }

  def answer(trigger: self.trigger)
    described_class.new(chat: chat, trigger: trigger).call
  end

  before { allow(Ai).to receive(:reply_in).and_return("Нічим") }

  it "answers the latest message, telling the model which one it is" do
    expect(answer).to eq("Нічим")
    expect(Ai).to have_received(:reply_in).with(chat, target: trigger, frame_paths: [])
  end

  it "stays silent when the model decides the message isn't for it" do
    allow(Ai).to receive(:reply_in).and_return(" skip. ")

    expect(answer).to eq(Response::STOP)
  end

  it "doesn't ask the model when someone has written since" do
    trigger
    create(:message, chat: chat, telegram_message_id: 11)

    expect(answer).to eq(Response::STOP)
    expect(Ai).not_to have_received(:reply_in)
  end

  it "drops the reply when someone writes while the model is answering" do
    allow(Ai).to receive(:reply_in) do
      create(:message, chat: chat, telegram_message_id: 11)
      "Нічим"
    end

    expect(answer).to eq(Response::STOP)
  end

  it "still answers a message that mentions the bot" do
    mention = create(:message, chat: chat, content: "@Test_Bot ти тут?", telegram_message_id: 10)
    create(:message, chat: chat, telegram_message_id: 11)

    expect(answer(trigger: mention)).to eq("Нічим")
  end

  it "ignores the bot's own newer messages" do
    trigger
    create(:message, chat: chat, role: :assistant, user: nil, telegram_message_id: 11)

    expect(answer).to eq("Нічим")
  end

  it "ignores newer messages in other chats" do
    trigger
    create(:message, telegram_message_id: 11)

    expect(answer).to eq("Нічим")
  end

  it "answers without checking when there's no trigger (video notes)" do
    create(:message, chat: chat, telegram_message_id: 11)

    expect(described_class.new(chat: chat).call).to eq("Нічим")
  end
end
