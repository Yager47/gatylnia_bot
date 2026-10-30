module Camerton
  # Re-derives a review's score and summary from all of its messages, then
  # reacts to the latest one with the result and, when the score changed,
  # tells the release's sharers (SharerNotice). A review only gets a score
  # its author wrote; without one it keeps just the summary. Neither that nor
  # messages that aren't a review clear an existing score: it may have come
  # from outside the chat (a spreadsheet import), with no messages behind
  # it, or from before scores had to be written out.
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
      return if !result.review && @review.score

      previous_score = @review.score
      Review.transaction do
        @review.update!(score: result.score || previous_score, summary: result.summary, scored_at: Time.current)
        record_change(previous_score)
      end
      # Even with the score unchanged: a new message can make the review
      # longer or add a voice note, which achievements count.
      CheckAchievementsJob.perform_later(@review.chat)
      return unless @react

      ReviewReaction.new(@review).call
      SharerNotice.new(@review).call if @review.score && @review.score != previous_score
    end

    private

    # A member changing their mind, for Перевзувач. Silent scoring (imports,
    # merges) re-reads old messages: a different score there isn't theirs.
    def record_change(previous_score)
      return unless @react && previous_score && @review.score && @review.score != previous_score

      @review.score_changes.create!(from_score: previous_score, to_score: @review.score, changed_at: @review.scored_at)
    end

    def analyzer
      @analyzer ||= FeedbackAnalyzer.new
    end
  end
end
