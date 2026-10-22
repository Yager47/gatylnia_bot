require "rails_helper"

RSpec.describe Response::RpsGame do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, chats: [ chat ]) }

  # Array#sample(random:) asks for rand(3): 0 = камінь, 1 = папір, 2 = ножиці.
  def play(weapon, bot_index:)
    described_class.new(user: user, user_weapon: weapon, chat: chat, random: double(rand: bot_index)).call
  end

  it "pays the stake for a win" do
    expect(play("камінь", bot_index: 2)).to end_with("Камінь > Ножиці. +10 жмихкоїнів")
    expect(Point.sole).to have_attributes(user: user, chat: chat, amount: 10, reason: "RPS: камінь > ножиці")
  end

  it "takes the stake for a loss" do
    expect(play("камінь", bot_index: 1)).to end_with("Камінь < Папір. -10 жмихкоїнів")
    expect(Point.sole.amount).to eq(-10)
  end

  it "answers a draw without points" do
    expect(AnswerFiles.yaml("answers", "rps_draw").flatten).to include(play("папір", bot_index: 1))
    expect(Point.count).to eq(0)
  end

  it "ignores anything that isn't a weapon" do
    expect(play("баланс", bot_index: 0)).to be_nil
  end
end
