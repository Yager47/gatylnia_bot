require "rails_helper"

RSpec.describe Plural do
  describe ".word" do
    it "picks the Ukrainian plural form" do
      forms = [ 0, 1, 2, 4, 5, 11, 12, 14, 20, 21, 22, 25, 101, 111, 112 ].index_with do |number|
        described_class.word(number, "кава", "кави", "кав")
      end

      expect(forms).to eq(
        0 => "кав", 1 => "кава", 2 => "кави", 4 => "кави", 5 => "кав", 11 => "кав", 12 => "кав", 14 => "кав",
        20 => "кав", 21 => "кава", 22 => "кави", 25 => "кав", 101 => "кава", 111 => "кав", 112 => "кав"
      )
    end

    it "uses the absolute value for negative numbers" do
      expect([ -1, -3, -21, -11 ].map { |number| described_class.word(number, "кава", "кави", "кав") }).to eq(%w[кава кави кава кав])
    end
  end

  describe ".count" do
    it "puts the number before the word" do
      expect(described_class.count(21, "оцінка", "оцінки", "оцінок")).to eq("21 оцінка")
      expect(described_class.count(-3, "кава", "кави", "кав")).to eq("-3 кави")
    end
  end
end
