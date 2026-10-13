require "rails_helper"

RSpec.describe ScoreReviewJob do
  let(:review) { create(:review) }

  it "scores the review, reacting unless told not to" do
    scoring = instance_double(Camerton::ReviewScoring, call: nil)
    allow(Camerton::ReviewScoring).to receive(:new).and_return(scoring)

    described_class.perform_now(review)
    described_class.perform_now(review, react: false)

    expect(Camerton::ReviewScoring).to have_received(:new).with(review, react: true)
    expect(Camerton::ReviewScoring).to have_received(:new).with(review, react: false)
    expect(scoring).to have_received(:call).twice
  end

  it "runs one job per review at a time" do
    expect(described_class.new(review).concurrency_key).to eq(described_class.new(Review.find(review.id)).concurrency_key)
    expect(described_class.new(review).concurrency_key).not_to eq(described_class.new(create(:review)).concurrency_key)
    expect(described_class.concurrency_limit).to eq(1)
  end

  it "retries when OpenAI is unreachable" do
    create(:review_message, review: review)
    allow_any_instance_of(Camerton::FeedbackAnalyzer).to receive(:call)
      .and_raise(OpenAI::Errors::APIConnectionError.new(url: URI("https://api.openai.com"), request: nil))

    described_class.perform_now(review)

    expect(described_class).to have_been_enqueued.with(review)
  end
end
