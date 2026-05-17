require "test_helper"

class AiTest < ActiveSupport::TestCase
  test "vision_message encodes frame as base64 image_url" do
    frame = Tempfile.new(["frame", ".jpg"])
    frame.binmode
    frame.write("fake-image")
    frame.close

    message = Ai.send(:vision_message, "Іван надіслав кружочек", frame.path)
    image_part = message[:content].find { |part| part[:type] == "image_url" }

    assert_includes image_part[:image_url][:url], "data:image/jpeg;base64,"
  ensure
    frame.unlink
  end
end
