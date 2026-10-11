require "rails_helper"

RSpec.describe Activities::CoffeeTextClassifier do
  describe ".candidate?" do
    it "matches coffee words in any form and case" do
      [ "Перша кава", "п'ю каву", "кавуся", "випив кофе", "Еспресо!", "latte time", "капучино", "Americano" ].each do |text|
        expect(described_class.candidate?(text)).to be(true), text
      end
    end

    it "skips цікаво and unrelated text" do
      [ "Цікаво", "дуже цікава історія", "погатив", "", nil ].each do |text|
        expect(described_class.candidate?(text)).to be(false), text.inspect
      end
    end
  end

  describe "#call" do
    let(:completions) { double("completions") }
    let(:client) { double("OpenAI::Client", chat: double(completions: completions)) }

    def model_returns(json)
      message = double(content: JSON.generate(json))
      allow(completions).to receive(:create).and_return(double(choices: [ double(message: message) ]))
    end

    it "returns the model's verdict" do
      model_returns(coffee: true, cups: 1, ordinal: 2)

      result = described_class.new(client: client).call("Друга кава")

      expect(result).to eq(described_class::Result.new(coffee: true, cups: 1, ordinal: 2))
      expect(completions).to have_received(:create).with(
        hash_including(model: "gpt-5-mini", messages: include({ role: "user", content: "Друга кава" }))
      )
    end

    it "keeps the cup count between 1 and 5" do
      model_returns(coffee: true, cups: 40, ordinal: nil)
      expect(described_class.new(client: client).call("40 кав").cups).to eq(5)

      model_returns(coffee: true, cups: 0, ordinal: nil)
      expect(described_class.new(client: client).call("кава").cups).to eq(1)
    end
  end
end
