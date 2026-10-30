require "rails_helper"

RSpec.describe Camerton::ReviewReaction do
  let(:review) { create(:review) }

  def reactions_sent
    fake_telegram.calls.select { |name, _| name == :set_message_reaction }.map(&:last)
  end

  def sent_emojis
    reactions_sent.sole[:reaction].map(&:emoji)
  end

  it "reacts to the latest message of the review" do
    create(:review_message, review: review, telegram_message_id: 100, sent_at: 2.days.ago)
    create(:review_message, review: review, telegram_message_id: 101, sent_at: 1.hour.ago)
    review.update!(score: 9)

    described_class.new(review).call

    expect(reactions_sent.sole).to include(chat_id: review.chat.telegram_id, message_id: 101)
  end

  it "picks the emoji by score: swearing for bad, then mid, good, great" do
    create(:review_message, review: review)

    { 1 => "🤬", 3 => "🤬", 4 => "🤔", 5 => "🤔", 6 => "👍", 8 => "👍", 9 => "🔥", 10 => "🔥" }.each do |score, emoji|
      fake_telegram.calls.clear
      review.update!(score: score)

      described_class.new(review).call

      expect(sent_emojis).to eq([ emoji ]), "score #{score}"
    end
  end

  it "writes ✍ on a review without a written score" do
    create(:review_message, review: review)
    review.update!(score: nil, summary: "каже, що приспів топ")

    described_class.new(review).call

    expect(sent_emojis).to eq([ "✍" ])
  end

  it "clears its reaction when the replies aren't a review" do
    create(:review_message, review: review)

    described_class.new(review).call

    expect(reactions_sent.sole[:reaction]).to eq([])
  end

  it "only logs a failure, so scoring isn't retried for a cosmetic reaction" do
    create(:review_message, review: review)
    review.update!(score: 7)
    response = instance_double(Faraday::Response, status: 400, body: { ok: false, error_code: 400, description: "Bad Request: REACTION_INVALID" }.to_json)
    allow(fake_telegram).to receive(:set_message_reaction).and_raise(Telegram::Bot::Exceptions::ResponseError.new(response: response))
    allow(Rails.logger).to receive(:warn)

    expect { described_class.new(review).call }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(/REACTION_INVALID/)
  end

  describe "#clear" do
    it "takes the reaction off every message of the review" do
      create(:review_message, review: review, telegram_message_id: 100)
      create(:review_message, review: review, telegram_message_id: 101)

      described_class.new(review).clear

      expect(reactions_sent).to contain_exactly(
        { chat_id: review.chat.telegram_id, message_id: 100, reaction: [] },
        { chat_id: review.chat.telegram_id, message_id: 101, reaction: [] }
      )
    end

    it "only logs a failure and goes on with the next message" do
      create_list(:review_message, 2, review: review)
      response = instance_double(Faraday::Response, status: 400, body: { ok: false, error_code: 400, description: "Bad Request: MESSAGE_ID_INVALID" }.to_json)
      allow(fake_telegram).to receive(:set_message_reaction).and_raise(Telegram::Bot::Exceptions::ResponseError.new(response: response))
      allow(Rails.logger).to receive(:warn)

      expect { described_class.new(review).clear }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).twice
    end
  end
end
