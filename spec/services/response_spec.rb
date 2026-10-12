require "rails_helper"

RSpec.describe Response do
  describe ".first" do
    it "returns the first reply and doesn't call the responders after it" do
      later = -> { raise "should not be called" }

      expect(described_class.first([ -> { nil }, -> { "перша" }, later ])).to eq("перша")
    end

    it "stops at STOP without a reply" do
      later = -> { raise "should not be called" }

      expect(described_class.first([ -> { Response::STOP }, later ])).to eq(Response::STOP)
    end

    it "returns nil when no responder answers" do
      expect(described_class.first([ -> { nil }, -> { nil } ])).to be_nil
    end
  end
end
