require "rails_helper"

RSpec.describe Removals::RequestClassifier do
  describe ".candidate?" do
    it "needs a removal verb and a word for one of the chat's kinds" do
      [ "видали останню каву", "Прибери каву", "скасуй гатіння", "забери моє останнє гатіння", "видали мою оцінку", "прибери моє рев'ю" ].each do |text|
        expect(described_class.candidate?(text, %w[coffee gato review])).to be(true), text
      end
    end

    it "skips commands without a removal verb or without a kind's word" do
      [ "кава за тиждень", "видали замітки", "прибери тут", "", nil ].each do |text|
        expect(described_class.candidate?(text, %w[coffee gato review])).to be(false), text.inspect
      end
    end

    it "only looks for the kinds asked about" do
      expect(described_class.candidate?("видали каву", %w[review])).to be(false)
      expect(described_class.candidate?("видали оцінку", %w[coffee gato])).to be(false)
      expect(described_class.candidate?("видали каву", [])).to be(false)
    end
  end

  describe "#call" do
    let(:completions) { double("completions") }
    let(:client) { double("OpenAI::Client", chat: double(completions: completions)) }

    def model_returns(kind)
      message = double(content: JSON.generate(kind: kind))
      allow(completions).to receive(:create).and_return(double(choices: [ double(message: message) ]))
    end

    def classify(command, kinds: %w[coffee gato])
      described_class.new(client: client).call(command, kinds: kinds)
    end

    it "returns the kind the model names" do
      model_returns("coffee")

      expect(classify("прибери каву")).to eq("coffee")
      expect(completions).to have_received(:create).with(
        hash_including(model: "gpt-5-mini", messages: include({ role: "user", content: "прибери каву" }))
      )
    end

    it "returns nil for none" do
      model_returns("none")

      expect(classify("не видаляй каву")).to be_nil
    end

    # strict json_schema already limits it; this is the code's own guard.
    it "never returns a kind the chat doesn't have" do
      model_returns("review")

      expect(classify("видали оцінку")).to be_nil
    end

    it "offers the model only the chat's kinds, plus none" do
      model_returns("none")

      classify("видали каву", kinds: %w[review])

      expect(completions).to have_received(:create) do |params|
        expect(params.dig(:response_format, :json_schema, :schema, :properties, :kind, :enum)).to eq(%w[review none])
        prompt = params[:messages].first[:content]
        expect(prompt).to include("review:")
        expect(prompt).not_to include("coffee:", "gato:")
      end
    end

    it "tells the model that other people's, several or older records are none" do
      model_returns("none")

      classify("видали каву")

      expect(completions).to have_received(:create) do |params|
        expect(params[:messages].first[:content]).to include("видали каву Олі", "видали всі кави", "не видаляй каву")
      end
    end
  end
end
