require "rails_helper"

RSpec.describe Ai do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  def frame(name, bytes)
    File.join(@dir, name).tap { |path| File.binwrite(path, bytes) }
  end

  describe ".vision_message" do
    it "encodes every frame as a low-detail base64 image, in order" do
      message = described_class.send(:vision_message, "Іван надіслав кружочек", [ frame("a.jpg", "one"), frame("b.jpg", "two") ])
      urls = message[:content].select { |part| part[:type] == "image_url" }.map { |part| part[:image_url] }

      expect(message[:content].first).to eq({ type: "text", text: "Іван надіслав кружочек\nКадри з цього відео, по порядку:" })
      expect(urls).to eq([
        { url: "data:image/jpeg;base64,#{Base64.strict_encode64('one')}", detail: "low" },
        { url: "data:image/jpeg;base64,#{Base64.strict_encode64('two')}", detail: "low" }
      ])
    end
  end

  describe ".messages" do
    let(:chat) { create(:chat) }
    let(:petro) { create(:user, first_name: "Петро", last_name: nil) }
    let!(:video) { create(:message, chat: chat, user: petro, content: "Петро записав відео 10s.", created_at: 2.minutes.ago) }
    let!(:later_text) { create(:message, chat: chat, content: "а я вже пообідав", created_at: 1.minute.ago) }

    def messages(**options)
      described_class.send(:messages, chat, **options)
    end

    it "attaches the frames to the video message even when someone wrote after it" do
      result = messages(frames_for: video, frame_paths: [ frame("a.jpg", "one") ])

      with_images = result.select { |message| message[:content].is_a?(Array) }
      expect(with_images.size).to eq(1)
      expect(with_images.first[:content].first[:text]).to start_with(video.ai_context)
      expect(result).to include({ role: "user", content: later_text.ai_context })
    end

    it "ends with a note to answer that video" do
      expect(messages(frames_for: video, frame_paths: [ frame("a.jpg", "one") ]).last)
        .to eq({ role: "system", content: "Зараз відповідай саме на відео від Петро, а не на інші повідомлення." })
    end

    it "sends plain text history without a video" do
      result = messages(frames_for: nil, frame_paths: [])

      expect(result.map { |message| message[:content] }).to all(be_a(String))
      expect(result.last).to eq({ role: "user", content: later_text.ai_context })
    end
  end
end
