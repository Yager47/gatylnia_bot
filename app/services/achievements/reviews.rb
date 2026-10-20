module Achievements
  # The reviews achievements count: scored, and dated by their first message,
  # so a re-score or a later reply never moves a review into another period.
  # Reviews with no messages (scores from a ratings file) have no date and
  # never count.
  module Reviews
    module_function

    # One subquery per review over index_review_messages_on_review_id: fine
    # for a chat's few thousand reviews. Past that, store the first message
    # time on reviews instead.
    def first_sent_in(chat, range)
      Review.where(chat: chat).where.not(score: nil)
        .where(<<~SQL.squish, range.begin, range.end)
          (SELECT MIN(review_messages.sent_at) FROM review_messages
           WHERE review_messages.review_id = reviews.id) BETWEEN ? AND ?
        SQL
    end
  end
end
