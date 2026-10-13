module Camerton
  # Stores one reply as part of a member's review of the shared release and
  # has the review re-scored. Writing the same text again is a no-op (a
  # redelivery); different text replaces it (an edit).
  class ReviewWriter
    def initialize(share:, user:)
      @share = share
      @user = user
    end

    # Returns the ReviewMessage. score: false leaves scoring to the caller
    # (an import scores each review once, after all its messages).
    def write(telegram_message_id:, source:, text:, sent_at:, score: true)
      review = find_or_create_review
      review_message = find_or_create_message(review, telegram_message_id, source, text, sent_at)
      unless review_message.previously_new_record?
        return review_message if review_message.text == text

        review_message.update!(text: text)
      end

      ScoreReviewJob.perform_later(review) if score
      review_message
    end

    private

    def find_or_create_review
      attributes = { chat_id: @share.chat_id, release_id: @share.release_id, user: @user }
      Review.find_by(attributes) || Review.create_or_find_by!(attributes)
    end

    def find_or_create_message(review, telegram_message_id, source, text, sent_at)
      attributes = { release_share: @share, telegram_message_id: telegram_message_id }
      ReviewMessage.find_by(attributes) ||
        ReviewMessage.create_or_find_by!(attributes) do |review_message|
          review_message.review = review
          review_message.source = source
          review_message.text = text
          review_message.sent_at = sent_at
        end
    end
  end
end
