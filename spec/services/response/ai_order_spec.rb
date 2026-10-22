require "rails_helper"

RSpec.describe Response::AiOrder do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, first_name: "Іван", chats: [ chat ]) }
  let!(:olga) { create(:user, first_name: "Ольга", last_name: nil, username: "Olga_K", chats: [ chat ]) }

  let!(:savings) { create(:point, user: user, chat: chat, amount: 150) }

  def order(command)
    described_class.new(user: user, command: command, chat: chat).call
  end

  # The points orders took.
  def fees
    Point.where.not(id: savings.id)
  end

  before { allow(Ai).to receive(:compose).and_return("ти граєш як метроном без батарейки") }

  describe "roasts" do
    it "roasts the named member with the AI and charges 150" do
      expect(order("образь @olga_k")).to eq("Іван за 150 жмихкоїнів замовив: \n\n@Olga_K ти граєш як метроном без батарейки")
      expect(fees.sole).to have_attributes(user: user, chat: chat, amount: -150, reason: "образь @olga_k", giver: nil)
      expect(Ai).to have_received(:compose).with(chat, a_string_including("образу для Ольга"))
    end

    it "roasts a random member other than the author" do
      expect(order("образь когось")).to start_with("Іван за 150 жмихкоїнів замовив: \n\n@Olga_K ")
    end

    it "names a member without a username instead of mentioning" do
      olga.update!(username: nil)

      expect(order("образь когось")).to include("\n\nОльга ти граєш")
    end

    it "charges nothing when there's nobody else to roast" do
      olga.destroy!

      expect(order("образь когось")).to eq("Нема кого ображати.")
      expect(fees.count).to eq(0)
    end

    it "takes a balance down to exactly zero" do
      order("образь когось")

      expect(Zhmykhcoins.balance(user, chat)).to eq(0)
    end

    it "refuses a roast the balance doesn't cover, without asking the AI or charging" do
      savings.update!(amount: 149)

      expect(order("образь @olga_k")).to eq("Це коштує 150 жмихкоїнів, а в тебе 149 жмихкоїнів. Спершу назбирай.")
      expect(order("образь когось")).to start_with("Це коштує 150")
      expect(order("образь @nobody")).to start_with("Це коштує 150")
      expect(fees.count).to eq(0)
      expect(Ai).not_to have_received(:compose)
    end

    it "refuses when the balance was spent while the AI wrote" do
      allow(Ai).to receive(:compose) do
        create(:point, user: user, chat: chat, amount: -1)
        "текст"
      end

      expect(order("образь @olga_k")).to start_with("Це коштує 150 жмихкоїнів, а в тебе 149")
      expect(fees.where(amount: -150)).to be_empty
    end

    it "still charges for a username nobody here has, without asking the AI" do
      expect(order("образь @nobody")).to eq("Такої людини тут нема, але 150 жмихкоїнів я все одно забрав. Шоб не вмикала чєпуха.")
      expect(fees.sole.amount).to eq(-150)
      expect(Ai).not_to have_received(:compose)
    end
  end

  describe "anecdotes" do
    it "tells one on a topic from the list for 50" do
      expect(order("анекдот")).to eq("Іван замовив анекдот за 50 жмихкоїнів:\n\nти граєш як метроном без батарейки")
      expect(fees.sole.amount).to eq(-50)
      expect(Ai).to have_received(:compose).with(chat, satisfy { |task| described_class::TOPICS.any? { |topic| task.include?("про #{topic}.") } })
    end

    it "may take a balance below zero" do
      savings.destroy!

      expect(order("анекдот")).to start_with("Іван замовив анекдот")
      expect(Zhmykhcoins.balance(user, chat)).to eq(-50)
    end

    it "takes the topic from the command" do
      order("анекдот про басиста")

      expect(Ai).to have_received(:compose).with(chat, a_string_including("анекдот (до 80 слів) про басиста."))
    end
  end

  describe "when the AI doesn't deliver" do
    it "charges nothing when OpenAI fails" do
      allow(Ai).to receive(:compose).and_raise(OpenAI::Errors::APIConnectionError.new(url: URI("https://api.openai.com"), request: nil))

      expect(order("анекдот")).to eq(described_class::UNAVAILABLE)
      expect(fees.count).to eq(0)
    end

    it "charges nothing for an empty answer or SKIP" do
      allow(Ai).to receive(:compose).and_return(" ", "SKIP.")

      expect(order("образь @olga_k")).to eq(described_class::UNAVAILABLE)
      expect(order("анекдот")).to eq(described_class::UNAVAILABLE)
      expect(fees.count).to eq(0)
    end
  end

  it "ignores other commands" do
    expect(order("образь мене")).to be_nil
    expect(order("анекдоти")).to be_nil
  end
end
