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

  describe "checking achievements" do
    before { create(:review_message, review: review) }

    def score_as(score, react: true)
      allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: !score.nil?, score: score, summary: "ok"))
      described_class.new(review, analyzer: analyzer, react: react).call
    end

    it "checks the chat after every scoring, even silent or with the score unchanged" do
      review.update!(score: 7)

      score_as(7, react: false)

      expect(CheckAchievementsJob).to have_been_enqueued.with(review.chat)
    end

    it "records a member changing their score, but not a first score or a silent re-score" do
      score_as(5)
      expect(review.score_changes).to be_empty

      score_as(8)
      expect(review.score_changes.sole).to have_attributes(from_score: 5, to_score: 8, changed_at: review.reload.scored_at)

      score_as(8)
      score_as(3, react: false)
      expect(review.score_changes.count).to eq(1)
    end

    it "doesn't when the messages turn out not to be a review and the old score stays" do
      review.update!(score: 7)

      score_as(nil)

      expect(CheckAchievementsJob).not_to have_been_enqueued
    end
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

  it "records a review without a written score with its summary only, and reacts with ✍" do
    create(:review_message, review: review, text: "приспів топ, інтро затягнуте")
    allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: nil, summary: "каже, що приспів топ"))

    described_class.new(review, analyzer: analyzer).call

    expect(review.reload).to have_attributes(score: nil, summary: "каже, що приспів топ")
    _name, params = fake_telegram.calls.find { |name, _| name == :set_message_reaction }
    expect(params[:reaction].map(&:emoji)).to eq([ "✍" ])
    expect(fake_telegram.sent_messages).to be_empty
  end

  it "keeps an existing score but takes the new summary when a review has no written score" do
    review.update!(score: 7, summary: "старе")
    create(:review_message, review: review, text: "з часом ще краще")
    allow(analyzer).to receive(:call).and_return(Camerton::FeedbackAnalyzer::Result.new(review: true, score: nil, summary: "з часом ще краще"))

    described_class.new(review, analyzer: analyzer).call

    expect(review.reload).to have_attributes(score: 7, summary: "з часом ще краще")
    expect(review.score_changes).to be_empty
    expect(fake_telegram.sent_messages).to be_empty
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
