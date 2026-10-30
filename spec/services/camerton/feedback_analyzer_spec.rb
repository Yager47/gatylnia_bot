require "rails_helper"

RSpec.describe Camerton::FeedbackAnalyzer do
  let(:completions) { double("completions") }
  let(:client) { double("OpenAI::Client", chat: double(completions: completions)) }
  let(:release) { build(:release, :resolved) }
  let(:messages) do
    [
      build(:review_message, text: "спочатку не зайшло", sent_at: Time.zone.local(2026, 10, 1, 12)),
      build(:review_message, source: :voice, text: "а тепер вісім з десяти", sent_at: Time.zone.local(2026, 10, 13, 12))
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
          { "date" => "2026-10-01", "source" => "text", "text" => "спочатку не зайшло" },
          { "date" => "2026-10-13", "source" => "voice", "text" => "а тепер вісім з десяти" }
        ]
      )
    end
  end

  it "drops the score and summary when the replies aren't a review" do
    model_returns(review: false, score: 5, summary: "щось")

    expect(analyze).to eq(described_class::Result.new(review: false, score: nil, summary: nil))
  end

  it "keeps the summary of a review without a written score" do
    model_returns(review: true, score: nil, summary: "каже, що приспів топ")

    expect(analyze).to eq(described_class::Result.new(review: true, score: nil, summary: "каже, що приспів топ"))
  end

  it "has no summary for a bare score" do
    model_returns(review: true, score: 8, summary: "")

    expect(analyze).to eq(described_class::Result.new(review: true, score: 8, summary: nil))
  end

  it "tells the model not to make up a summary for a bare score" do
    expect(described_class::PROMPT).to include("never add opinions or words of your own", "only gave a rating")
  end

  it "keeps a score the model returns out of range within 1-10" do
    model_returns(review: true, score: 11, summary: "шедевр")

    expect(analyze.score).to eq(10)
  end

  it "tells the model to take only written scores, the latest one, and that transcripts may be off" do
    expect(described_class::PROMPT).to include("7/10", "never guess a score", "the latest rating counts", "speech transcripts")
  end
end
