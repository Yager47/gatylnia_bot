require "rails_helper"

RSpec.describe Response::Reply do
  let(:chat) { create(:chat) }
  let(:giver) { create(:user, chats: [ chat ]) }
  let(:receiver) { create(:user, telegram_id: "777", first_name: "Ольга", last_name: nil, chats: [ chat ]) }
  let(:replied_message) { { from: { id: 777 }, text: "смішний жарт" }.with_indifferent_access }

  def reply_with(text, user: giver, reply_to_message: replied_message, in_chat: chat)
    receiver
    described_class.new(user: user, chat: in_chat, text: text, reply_to_message: reply_to_message).call
  end

  it "gives the replied-to author the жмихкоїни, with the message as the reason" do
    expect(reply_with("+50")).to eq("Ольга отримує +50 жмихкоїнів по причині: \n\"смішний жарт\"")
    expect(Point.sole).to have_attributes(user: receiver, giver: giver, chat: chat, amount: 50, reason: "смішний жарт")
  end

  it "calls the receiver by their pseudonym in this chat" do
    receiver.chat_users.find_by!(chat: chat).update!(pseudonym: "Сер Гатило")

    expect(reply_with("+50")).to start_with("Сер Гатило отримує +50")
  end

  it "ignores a bare number: it takes a sign to give" do
    expect(reply_with("100")).to be_nil
    expect(Point.count).to eq(0)
  end

  it "reads the number in base 10 and ignores surrounding spaces" do
    expect(reply_with(" +08 ")).to start_with("Ольга отримує +8 жмихкоїнів")
  end

  it "ignores a number inside other text" do
    expect(reply_with("+50 за жарт")).to be_nil
    expect(reply_with("+ 50")).to be_nil
  end

  it "accepts negative amounts" do
    expect(reply_with("-21")).to start_with("Ольга отримує -21 жмихкоїн ")
  end

  describe "daily budget" do
    it "allows 500 at once" do
      expect(reply_with("+500")).to start_with("Ольга отримує +500")
      expect(reply_with("-500", user: receiver, reply_to_message: { from: { id: giver.telegram_id.to_i } }.with_indifferent_access))
        .to start_with("#{giver.name} отримує -500")
    end

    it "counts gives and takes together and refuses what doesn't fit, without creating a point" do
      reply_with("+300")
      reply_with("-150")

      expect(reply_with("+51")).to eq("Сьогодні можна вʼєбать ще лише 50 жмихкоїнів, ліміт — пʼятихатка на день")
      expect(reply_with("-51")).to eq("Сьогодні можна вʼєбать ще лише 50 жмихкоїнів, ліміт — пʼятихатка на день")
      expect(Point.count).to eq(2)

      expect(reply_with("-50")).to start_with("Ольга отримує -50")
      expect(reply_with("+1")).to eq("Пʼятихатку жмихкоїнів на сьогодні вже вʼєбано, приходь завтра")
    end

    it "refuses more than 500 at once" do
      expect(reply_with("+501")).to start_with("Сьогодні можна вʼєбать ще лише 500 жмихкоїнів")
      expect(Point.count).to eq(0)
    end

    it "starts over at Kyiv midnight" do
      travel_to Time.zone.parse("2026-10-22 23:59") do
        reply_with("+500")
        expect(reply_with("+1")).to start_with("Пʼятихатку")
      end

      travel_to Time.zone.parse("2026-10-23 00:00") do
        expect(reply_with("+500")).to start_with("Ольга отримує +500")
      end
    end

    it "is kept per chat" do
      other_chat = create(:chat)
      reply_with("+500")

      expect(reply_with("+500", in_chat: other_chat)).to start_with("Ольга отримує +500")
    end

    it "is per giver, and ignores points nobody gave, like RPS results and bugging fees" do
      create(:point, user: giver, chat: chat, amount: -150)
      create(:point, user: receiver, giver: create(:user), chat: chat, amount: 500)

      expect(reply_with("+500")).to start_with("Ольга отримує +500")
    end
  end

  it "ignores text that isn't a number" do
    expect(reply_with("класно")).to be_nil
  end

  it "ignores zero" do
    expect(reply_with("+0")).to be_nil
    expect(Point.count).to eq(0)
  end

  it "ignores points for yourself and for unknown users" do
    expect(reply_with("+50", user: receiver)).to be_nil
    expect(reply_with("+50", reply_to_message: { from: { id: 999 } }.with_indifferent_access)).to be_nil
    expect(Point.count).to eq(0)
  end

  it "ignores a reply to a message without an author, like a channel post" do
    channel_post = { sender_chat: { id: -100, type: "channel" }, text: "новина" }.with_indifferent_access

    expect(reply_with("+50", reply_to_message: channel_post)).to be_nil
    expect(Point.count).to eq(0)
  end

  it "ignores messages that aren't replies" do
    expect(reply_with("+50", reply_to_message: nil)).to be_nil
  end
end
