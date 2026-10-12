require "rails_helper"

RSpec.describe Response::Reply do
  let(:chat) { create(:chat) }
  let(:giver) { create(:user, chats: [ chat ]) }
  let(:receiver) { create(:user, telegram_id: "777", first_name: "Ольга", last_name: nil, chats: [ chat ]) }
  let(:replied_message) { { from: { id: 777 }, text: "смішний жарт" }.with_indifferent_access }

  def reply_with(text, user: giver, reply_to_message: replied_message)
    receiver
    described_class.new(user: user, chat: chat, text: text, reply_to_message: reply_to_message).call
  end

  it "gives the replied-to author the points, with the message as the reason" do
    expect(reply_with("50")).to eq("Ольга отримує +50 по причині: \n\"смішний жарт\"")
    expect(Point.sole).to have_attributes(user: receiver, chat: chat, amount: 50, reason: "смішний жарт")
  end

  it "accepts negative points" do
    expect(reply_with("-20")).to start_with("Ольга отримує -20")
  end

  it "refuses more than 500 at once without creating a point" do
    expect(reply_with("501")).to eq("Не можна за раз більше пʼятихатки вʼєбать")
    expect(reply_with("-501")).to eq("Не можна за раз більше пʼятихатки вʼєбать")
    expect(Point.count).to eq(0)
  end

  it "ignores text that isn't a number" do
    expect(reply_with("класно")).to be_nil
  end

  it "ignores zero" do
    expect(reply_with("0")).to be_nil
    expect(Point.count).to eq(0)
  end

  it "ignores points for yourself and for unknown users" do
    expect(reply_with("50", user: receiver)).to be_nil
    expect(reply_with("50", reply_to_message: { from: { id: 999 } }.with_indifferent_access)).to be_nil
    expect(Point.count).to eq(0)
  end

  it "ignores a reply to a message without an author, like a channel post" do
    channel_post = { sender_chat: { id: -100, type: "channel" }, text: "новина" }.with_indifferent_access

    expect(reply_with("50", reply_to_message: channel_post)).to be_nil
    expect(Point.count).to eq(0)
  end

  it "ignores messages that aren't replies" do
    expect(reply_with("50", reply_to_message: nil)).to be_nil
  end
end
