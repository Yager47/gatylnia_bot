require "rails_helper"

RSpec.describe Response::Equals do
  def reply_to(text)
    described_class.new(user: build(:user), text: text).call
  end

  it "answers an exact phrase" do
    expect(reply_to("ало")).to eq("Ало")
  end

  it "throws an insult after \"ти \" back" do
    expect(reply_to("ти мразь")).to eq("Ти шо сука").or eq("Ні, ти мразь")
  end

  it "doesn't treat any three leading characters as \"ти \"" do
    expect(reply_to("ну мразь")).to be_nil
  end
end
