require "rails_helper"

RSpec.describe Camerton::FeedbackAnalyzer do
  let(:completions) { double("completions") }
  let(:client) { double("OpenAI::Client", chat: double(completions: completions)) }
  let(:release) { build(:release, :resolved) }
  let(:messages) do
    [
      build(:review_message, text: "спочатку не зайшло", sent_at: Time.zone.local(2026, 10, 1, 12)),
      build(:review_message, text: "а тепер 8/10", sent_at: Time.zone.local(2026, 10, 13, 12))
    ]
  end

  def model_returns(json)
    message = double(content: JSON.generate(json))
    allow(completions).to receive(:create).and_return(double(choices: [ double(message: message) ]))
  end

  def analyze
    described_class.new(client: client).call(release: release, messages: messages)
  end

  it "sends the release and every reply in order, and returns the verdict" do
    model_returns(review: true, score: 8, summary: " каже, що з часом зайшло ")

    expect(analyze).to eq(described_class::Result.new(review: true, score: 8, summary: "каже, що з часом зайшло"))
    expect(completions).to have_received(:create) do |params|
      expect(params[:model]).to eq("gpt-5-mini")
      expect(JSON.parse(params[:messages].last[:content])).to eq(
        "release" => { "kind" => "song", "artist" => "Queen", "title" => "Bohemian Rhapsody" },
        "replies" => [
          { "date" => "2026-10-01", "text" => "спочатку не зайшло" },
          { "date" => "2026-10-13", "text" => "а тепер 8/10" }
        ]
      )
    end
  end

  it "drops the score and summary when the replies aren't a review" do
    model_returns(review: false, score: 5, summary: "щось")

    expect(analyze).to eq(described_class::Result.new(review: false, score: nil, summary: nil))
  end

  it "keeps a score the model returns out of range within 1-10" do
    model_returns(review: true, score: 11, summary: "шедевр")

    expect(analyze.score).to eq(10)
  end

  it "tells the model that explicit ratings win and the latest opinion matters most" do
    expect(described_class::PROMPT).to include("7/10", "latest replies matter most")
  end
end
