require "rails_helper"

RSpec.describe Response::Includes do
  def reply_to(text)
    allow_any_instance_of(described_class).to receive(:pick) { |_, value| value }
    described_class.new(first_name: "Петро", text: text).call
  end

  it "answers the first rule whose word the message contains" do
    expect(reply_to("ну це кайф")).to eq("Кайф лютий")
  end

  it "matches any phrase from a phrases file" do
    expect(reply_to("дякую тобі")).to eq(AnswerFiles.yaml("answers", "thank"))
  end

  it "renders ERB answers with the author's first name" do
    expect(reply_to("добраніч").flatten.join).to include("Петро")
  end

  it "lets a stop rule end the chain without a reply" do
    expect(reply_to("рисова каша")).to eq(Response::STOP)
  end

  it "returns nil when nothing matches" do
    expect(reply_to("абв")).to be_nil
  end

  describe "word boundaries" do
    it "matches \"один\" at the start of a word only" do
      expect(reply_to("я один")).to eq("Проти цілого світу?")
      expect(reply_to("година пройшла")).to be_nil
    end

    it "matches \"рай\" as a whole word, anywhere in the message" do
      expect(reply_to("рай тут")).to eq("Тісний рай, получається")
      expect(reply_to("тісний район")).to be_nil
    end
  end

  describe "lib/rules/includes.yml" do
    let(:rules) { described_class.rules }

    it "has one matcher and one reply per rule" do
      rules.each do |rule|
        expect(rule.keys & %w[contains phrases pattern]).to have_attributes(size: 1), rule.inspect
        expect(rule.keys & %w[reply answers render stop]).to have_attributes(size: 1), rule.inspect
      end
    end

    it "only refers to files that exist" do
      rules.each do |rule|
        expect(Rails.root.join("lib/phrases/#{rule['phrases']}.yml")).to exist if rule["phrases"]
        expect(Rails.root.join("lib/answers/#{rule['answers']}.yml")).to exist if rule["answers"]
        expect(Rails.root.join("lib/answers/#{rule['render']}.yml.erb")).to exist if rule["render"]
      end
    end

    # A rule whose word contains an earlier rule's word can never match.
    it "has no rule shadowed by an earlier one" do
      words = rules.map { |rule| Array(rule["contains"]) }

      words.each_with_index do |later, index|
        later.each do |word|
          shadow = words.first(index).flatten.find { |earlier| word.include?(earlier) }
          expect(shadow).to be_nil, "#{word.inspect} is never reached: #{shadow.inspect} comes first"
        end
      end
    end
  end
end
