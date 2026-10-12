require "rails_helper"

RSpec.describe Video::NoteTranscriber do
  it "returns the transcript and closes the uploaded file" do
    uploaded = nil
    transcriptions = double("transcriptions")
    allow(transcriptions).to receive(:create) { |file:, **| uploaded = file; double(text: "привіт") }
    allow(OpenAI::Client).to receive(:new).and_return(double(audio: double(transcriptions: transcriptions)))

    Tempfile.create([ "note", ".mp4" ]) do |video|
      expect(described_class.call(video.path)).to eq("привіт")
    end

    expect(uploaded).to be_closed
  end
end
