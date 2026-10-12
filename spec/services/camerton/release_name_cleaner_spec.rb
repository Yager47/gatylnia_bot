require "rails_helper"

RSpec.describe Camerton::ReleaseNameCleaner do
  let(:completions) { double("completions") }
  let(:client) { double("OpenAI::Client", chat: double(completions: completions)) }

  def model_returns(json)
    message = double(content: JSON.generate(json))
    allow(completions).to receive(:create).and_return(double(choices: [ double(message: message) ]))
  end

  it "sends the kind, raw title and channel, and returns the cleaned names" do
    model_returns(artist: " Queen ", title: "Bohemian Rhapsody")
    source = Camerton::SourceMetadata.new(title: "Queen – Bohemian Rhapsody (Official Video Remastered)", author: "Queen Official")

    result = described_class.new(client: client).call(kind: "song", source: source)

    expect(result).to eq(described_class::Result.new(artist: "Queen", title: "Bohemian Rhapsody"))
    expect(completions).to have_received(:create) do |params|
      expect(params[:model]).to eq("gpt-5-mini")
      expect(JSON.parse(params[:messages].last[:content])).to eq(
        "kind" => "song", "title" => "Queen – Bohemian Rhapsody (Official Video Remastered)", "channel" => "Queen Official"
      )
      expect(params.dig(:response_format, :json_schema, :strict)).to be(true)
    end
  end

  it "tells the model how to handle Topic channels and album prefixes" do
    expect(described_class::PROMPT).to include(" - Topic", "Album - ")
  end
end
