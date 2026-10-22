require "rails_helper"

RSpec.describe Response::Pseudonym do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, first_name: "Петро", last_name: nil, chats: [ chat ]) }
  let!(:savings) { create(:point, user: user, chat: chat, amount: 1000) }

  def say(text, by: user)
    described_class.new(user: by, chat: chat, text: text).call
  end

  def pseudonym(of = user)
    chat.chat_users.find_by!(user: of).pseudonym
  end

  def fees
    Point.where("amount < 0")
  end

  describe "buying" do
    it "sets the pseudonym as written, for 500" do
      expect(say("@test_bot псевдонім Сер Гатило")).to eq("Тепер ти тут Сер Гатило. Це коштувало 500 жмихкоїнів.")
      expect(pseudonym).to eq("Сер Гатило")
      expect(fees.sole).to have_attributes(user: user, chat: chat, amount: -500, reason: "Псевдонім: Сер Гатило")
    end

    it "reads the mention and the command in any case, and squishes spaces" do
      say("@Test_Bot  Псевдонім   Сер   Гатило ")

      expect(pseudonym).to eq("Сер Гатило")
    end

    it "charges again for each change, but not for the same name" do
      say("@test_bot псевдонім Сер Гатило")

      expect(say("@test_bot псевдонім Сер Гатило")).to eq("Це вже твій псевдонім.")
      say("@test_bot псевдонім Барон Бласт")
      expect(pseudonym).to eq("Барон Бласт")
      expect(fees.count).to eq(2)
    end

    it "refuses when the balance doesn't cover it" do
      savings.update!(amount: 499)

      expect(say("@test_bot псевдонім Сер Гатило")).to eq("Це коштує 500 жмихкоїнів, а в тебе 499 жмихкоїнів. Спершу назбирай.")
      expect(pseudonym).to be_nil
      expect(fees).to be_empty
    end

    it "refuses a name another member here has, whatever the case, without charging" do
      olga = create(:user, chats: [ chat ])
      chat.chat_users.find_by!(user: olga).update!(pseudonym: "Сер Гатило")

      expect(say("@test_bot псевдонім СЕР ГАТИЛО")).to eq(described_class::TAKEN)
      expect(fees).to be_empty
    end

    it "allows a name someone has in another chat" do
      other_chat = create(:chat)
      ChatUser.create!(chat: other_chat, user: create(:user), pseudonym: "Сер Гатило")

      expect(say("@test_bot псевдонім Сер Гатило")).to start_with("Тепер ти тут")
    end

    it "refuses more than 32 characters" do
      expect(say("@test_bot псевдонім #{'я' * 33}")).to eq("Псевдонім до 32 символів.")
      expect(fees).to be_empty
    end

    it "rolls the fee back when someone takes the name at the same moment" do
      allow_any_instance_of(ChatUser).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

      expect(say("@test_bot псевдонім Сер Гатило")).to eq(described_class::TAKEN)
      expect(fees).to be_empty
    end

    it "explains how when the name is missing" do
      expect(say("@test_bot псевдонім")).to eq("Напиши, який: @test_bot псевдонім Сер Гатило. Коштує 500 жмихкоїнів.")
    end
  end

  describe "showing and removing" do
    it "shows the pseudonym, or how to buy one" do
      expect(say("@test_bot мій псевдонім")).to start_with("Псевдоніма нема, ти тут Петро.")

      say("@test_bot псевдонім Сер Гатило")
      expect(say("@test_bot мій псевдонім")).to eq("Твій псевдонім тут: Сер Гатило")
    end

    it "removes it for free with прибери or видали" do
      %w[прибери видали].each do |verb|
        say("@test_bot псевдонім Сер Гатило #{verb}")

        expect(say("@test_bot #{verb} псевдонім")).to eq("Псевдонім прибрано, ти знову Петро.")
        expect(pseudonym).to be_nil
      end
      expect(fees.count).to eq(2)
      expect(say("@test_bot прибери псевдонім")).to eq("У тебе й так нема псевдоніма.")
    end
  end

  it "ignores other text" do
    expect(say("@test_bot баланс")).to be_nil
    expect(say("псевдонім Сер Гатило")).to be_nil
    expect(say(nil)).to be_nil
  end
end
