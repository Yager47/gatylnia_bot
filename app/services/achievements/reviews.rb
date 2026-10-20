module Achievements
  # The reviews achievements count: scored, and dated by their first message,
  # so a re-score or a later reply never moves a review into another period.
  # Reviews with no messages (scores from a ratings file) have no date and
  # never count. Each relation exposes firsts.first_at (that message's time)
  # and firsts.first_share_id (the share it answered).
  module Reviews
    # One indexed lookup per review (index_review_messages_on_review_id):
    # fine for a chat's few thousand reviews. Past that, store the first
    # message on reviews instead.
    FIRST_MESSAGE = <<~SQL.squish.freeze
      JOIN LATERAL (
        SELECT review_messages.sent_at AS first_at, review_messages.release_share_id AS first_share_id
        FROM review_messages
        WHERE review_messages.review_id = reviews.id
        ORDER BY review_messages.sent_at, review_messages.id
        LIMIT 1
      ) firsts ON true
    SQL

    # The share the first message answered, as first_shares.
    FIRST_SHARE = "JOIN release_shares first_shares ON first_shares.id = firsts.first_share_id".freeze

    # Leaves out reviews of a release the reviewer shared in the chat
    # themselves: being quick or first under your own link proves nothing.
    NOT_OWN_SHARE = <<~SQL.squish.freeze
      NOT EXISTS (
        SELECT 1 FROM release_shares own_shares
        WHERE own_shares.chat_id = reviews.chat_id
          AND own_shares.release_id = reviews.release_id
          AND own_shares.user_id = reviews.user_id
      )
    SQL

    module_function

    def dated(chat)
      Review.where(chat: chat).where.not(score: nil).joins(FIRST_MESSAGE)
    end

    def first_sent_in(chat, range)
      dated(chat).where("firsts.first_at" => range)
    end

    # Reviews by members who didn't share the release, each with
    # ranked.first_at, ranked.shared_at (of the share it answered) and
    # ranked.release_first_at (the earliest such review of that release).
    def ranked(chat)
      listeners = dated(chat).joins(FIRST_SHARE).where(NOT_OWN_SHARE).select(<<~SQL.squish)
        reviews.user_id, firsts.first_at, first_shares.shared_at,
        MIN(firsts.first_at) OVER (PARTITION BY reviews.release_id) AS release_first_at
      SQL
      Review.from(listeners, :ranked)
    end
  end
end
