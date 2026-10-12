require "rails_helper"

RSpec.describe "canned responders" do
  describe Response::Voice do
    it "answers a voice message with a line from voice.yml" do
      expect(AnswerFiles.yaml("answers", "voice")).to include(described_class.new(voice: { file_id: "v" }).call)
    end

    it "ignores a message without voice" do
      expect(described_class.new(voice: nil).call).to be_nil
    end
  end

  describe Response::Forward do
    it "answers a forward with a line from forward.yml" do
      expect(AnswerFiles.yaml("answers", "forward")).to include(described_class.new(forward_from: { id: 1 }).call)
    end

    it "ignores a message that isn't a forward" do
      expect(described_class.new(forward_from: nil).call).to be_nil
    end
  end

  describe Response::Chance do
    it "renders chance.yml.erb with a rhythm and picks one line" do
      allow(TimeSignature).to receive(:call).and_return("7/8")

      expect(AnswerFiles.erb("answers", "chance", rhythm: "7/8").flatten).to include(described_class.new.call)
    end
  end
end
