require "rails_helper"

RSpec.describe Ai do
  describe ".vision_message" do
    it "encodes the frame as a base64 image_url" do
      frame = Tempfile.new([ "frame", ".jpg" ])
      frame.binmode
      frame.write("fake-image")
      frame.close

      message = described_class.send(:vision_message, "Іван надіслав кружочек", frame.path)
      image_part = message[:content].find { |part| part[:type] == "image_url" }

      expect(image_part[:image_url][:url]).to eq("data:image/jpeg;base64,#{Base64.strict_encode64('fake-image')}")
    ensure
      frame&.unlink
    end
  end
end
