require "rails_helper"

RSpec.describe Response::Equals do
  def reply_to(text)
    described_class.new(text: text).call
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

  it "answers from an answers file" do
    expect(AnswerFiles.yaml("answers", "god")).to include(reply_to("боже"))
  end

  it "throws an exact insult back" do
    expect(reply_to("мразь")).to eq("Ти шо сука").or eq("Ні, ти мразь")
  end

  it "ignores anything else" do
    expect(reply_to("ну добре")).to be_nil
  end

  it "has a reply or an answers file for every rule" do
    AnswerFiles.yaml("rules", "equals").each do |rule|
      expect(rule.keys & %w[reply answers]).to have_attributes(size: 1), rule.inspect
      expect(Rails.root.join("lib/answers/#{rule['answers']}.yml")).to exist if rule["answers"]
    end
  end
end
