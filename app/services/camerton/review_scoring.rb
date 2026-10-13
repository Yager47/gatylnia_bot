module Camerton
  # Re-derives a review's score and summary from all of its messages, then
  # reacts to the latest one with the result.
  class ReviewScoring
    # react: false scores silently (history imports).
    def initialize(review, analyzer: nil, react: true)
      @review = review
      @analyzer = analyzer
      @react = react
    end

    def call
      messages = @review.messages.order(:sent_at, :id).to_a
      return if messages.empty?

      result = analyzer.call(release: @review.release, messages: messages)
      @review.update!(score: result.score, summary: result.summary, scored_at: Time.current)
      ReviewReaction.new(@review).call if @react
    end

    private

    def analyzer
      @analyzer ||= FeedbackAnalyzer.new
    end
  end
end
