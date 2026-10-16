require "rails_helper"

RSpec.describe Camerton::ReviewScoring do
  let(:analyzer) { instance_double(Camerton::FeedbackAnalyzer) }
  let(:review) { create(:review) }

  it "scores the review from all its messages, oldest first" do
    later = create(:review_message, review: review, text: "тепер 8", sent_at: 1.hour.ago)
    earlier = create(:review_message, review: review, text: "спочатку 5", sent_at: 2.days.ago)
    allow(analyzer).to receive(:call)
      .with(release: review.release, messages: [ earlier, later ])
      .and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: 8, summary: "зайшло з часом"))

    freeze_time do
      described_class.new(review, analyzer: analyzer).call

      expect(review.reload).to have_attributes(score: 8, summary: "зайшло з часом", scored_at: Time.current)
    end
  end

  it "reacts to the latest message with the result" do
    create(:review_message, review: review, telegram_message_id: 100)
    allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: 2, summary: "не зайшло"))

    described_class.new(review, analyzer: analyzer).call

    _name, params = fake_telegram.calls.find { |name, _| name == :set_message_reaction }
    expect(params).to include(message_id: 100)
    expect(params[:reaction].map(&:emoji)).to eq([ "🤬" ])
  end

  it "scores without reacting when told not to" do
    create(:review_message, review: review)
    allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: 9, summary: "топ"))

    described_class.new(review, analyzer: analyzer, react: false).call

    expect(review.reload.score).to eq(9)
    expect(fake_telegram.calls).to be_empty
  end

  describe "telling the sharer" do
    let(:sharer) { create(:user, username: "olya") }
    let(:share) { create(:release_share, chat: review.chat, release: review.release, user: sharer) }

    before { create(:review_message, review: review, release_share: share) }

    def score_as(score)
      allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: score, summary: "ok"))
      described_class.new(review, analyzer: analyzer).call
    end

    it "posts the first score" do
      score_as(7)

      expect(fake_telegram.sent_messages.sole[:text]).to eq("@olya, твій реліз оцінили на 7/10 👍")
    end

    it "posts again when the score changes" do
      review.update!(score: 5)

      score_as(8)

      expect(fake_telegram.sent_messages.sole[:text]).to include("8/10")
    end

    it "stays quiet when a re-run keeps the score" do
      review.update!(score: 7)

      score_as(7)

      expect(fake_telegram.sent_messages).to be_empty
    end

    it "stays quiet when scoring silently" do
      allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: 7, summary: "ok"))

      described_class.new(review, analyzer: analyzer, react: false).call

      expect(fake_telegram.sent_messages).to be_empty
    end
  end

  it "keeps an existing score, without reacting, when the messages turn out not to be a review" do
    review.update!(score: 7, summary: "старе")
    create(:review_message, review: review, text: "де знайшов?")
    allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: false, score: nil, summary: nil))

    described_class.new(review, analyzer: analyzer).call

    expect(review.reload).to have_attributes(score: 7, summary: "старе")
    expect(fake_telegram.calls).to be_empty
  end

  it "records an unscored review when the messages aren't a review" do
    create(:review_message, review: review, text: "де знайшов?")
    allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: false, score: nil, summary: nil))

    freeze_time do
      described_class.new(review, analyzer: analyzer).call

      expect(review.reload).to have_attributes(score: nil, summary: nil, scored_at: Time.current)
    end
  end

  it "doesn't ask the model about a review without messages" do
    allow(analyzer).to receive(:call)

    described_class.new(review, analyzer: analyzer).call

    expect(analyzer).not_to have_received(:call)
  end
end
