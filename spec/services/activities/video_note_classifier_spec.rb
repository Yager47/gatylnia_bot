require "rails_helper"

RSpec.describe Activities::VideoNoteClassifier do
  let(:completions) { double("completions") }
  let(:client) { double("OpenAI::Client", chat: double(completions: completions)) }

  def model_returns(json)
    message = double(content: JSON.generate(json))
    allow(completions).to receive(:create).and_return(double(choices: [ double(message: message) ]))
  end

  def user_content
    request = nil
    expect(completions).to have_received(:create) { |params| request = params }
    request[:messages].find { |message| message[:role] == "user" }[:content]
  end

  it "sends the transcript and every frame as a low-detail image" do
    model_returns(coffee: true, ordinal: 2, push_ups: false)
    frame = Tempfile.new([ "frame", ".jpg" ])
    frame.binmode
    frame.write("fake-image")
    frame.close

    result = described_class.new(client: client).call(frame_paths: [ frame.path, frame.path ], transcript: "Друга кава")

    expect(result).to eq(described_class::Result.new(coffee: true, ordinal: 2, push_ups: false))
    expect(user_content.first).to eq({ type: "text", text: "Transcript: Друга кава" })
    images = user_content.select { |part| part[:type] == "image_url" }
    expect(images.size).to eq(2)
    expect(images.first[:image_url]).to eq({ url: "data:image/jpeg;base64,#{Base64.strict_encode64('fake-image')}", detail: "low" })
  ensure
    frame&.unlink
  end

  it "marks an empty transcript" do
    model_returns(coffee: false, ordinal: nil, push_ups: true)

    described_class.new(client: client).call(frame_paths: [], transcript: "")

    expect(user_content).to eq([ { type: "text", text: "Transcript: (empty)" } ])
  end

  describe "Result#kinds" do
    it "lists what the video shows" do
      expect(described_class::Result.new(coffee: true, ordinal: nil, push_ups: true).kinds).to eq(%i[coffee push_ups])
      expect(described_class::Result.new(coffee: false, ordinal: nil, push_ups: true).kinds).to eq(%i[push_ups])
      expect(described_class::Result.new(coffee: false, ordinal: nil, push_ups: false).kinds).to eq([])
    end
  end
end
