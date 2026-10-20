module Camerton
  # Re-derives a review's score and summary from all of its messages, then
  # reacts to the latest one with the result and, when the score changed,
  # tells the release's sharers (SharerNotice). Messages that aren't a review
  # never clear an existing score: it may have come from outside the chat
  # (a spreadsheet import), with no messages behind it.
  class ReviewScoring
    # react: false scores silently (history imports, merges).
    def initialize(review, analyzer: nil, react: true)
      @review = review
      @analyzer = analyzer
      @react = react
    end

    def call
      messages = @review.messages.order(:sent_at, :id).to_a
      return if messages.empty?

      result = analyzer.call(release: @review.release, messages: messages)
      return if result.score.nil? && @review.score

      previous_score = @review.score
      @review.update!(score: result.score, summary: result.summary, scored_at: Time.current)
      # Even with the score unchanged: a new message can make the review
      # longer or add a voice note, which achievements count.
      CheckAchievementsJob.perform_later(@review.chat)
      return unless @react

      ReviewReaction.new(@review).call
      SharerNotice.new(@review).call if @review.score && @review.score != previous_score
    end

    private

    def analyzer
      @analyzer ||= FeedbackAnalyzer.new
    end
  end
end
