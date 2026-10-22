require "rails_helper"

RSpec.describe Point do
  it "rejects a zero or fractional amount" do
    expect(build(:point, amount: 0)).not_to be_valid
    expect(build(:point, amount: 1.5)).not_to be_valid
  end

  it "accepts positive and negative whole amounts" do
    expect(build(:point, amount: 10)).to be_valid
    expect(build(:point, amount: -10)).to be_valid
  end

  it "keeps a given point when its giver is deleted" do
    giver = create(:user)
    point = create(:point, giver: giver)

    giver.destroy!

    expect(point.reload.giver).to be_nil
  end
end
