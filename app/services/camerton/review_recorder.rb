module Camerton
  # Stores a reply to a share as feedback, exactly as written, and has the
  # review re-scored. An edit replaces that message's text. Safe to run twice
  # for the same message: unchanged text is neither stored nor scored again.
  class ReviewRecorder
    def initialize(message:, chat:)
      @message = message
      @chat = chat
    end

    # Returns the ReviewMessage, or nil when the message isn't feedback.
    def call
      share = replied_share
      return unless share

      text = @message[:text] || @message[:caption]
      return if text.blank?

      review = find_or_create_review(share)
      review_message = find_or_create_message(review, share, text)
      unless review_message.previously_new_record?
        return review_message if review_message.text == text # a redelivery

        review_message.update!(text: text) # an edit
      end

      ScoreReviewJob.perform_later(review)
      review_message
    end

    private

    # The link message itself or the bot's announcement under it.
    def replied_share
      replied_id = @message.dig(:reply_to_message, :message_id)
      return unless replied_id

      @chat.release_shares
        .where(telegram_message_id: replied_id)
        .or(@chat.release_shares.where(announcement_telegram_message_id: replied_id))
        .first
    end

    def find_or_create_review(share)
      attributes = { chat: @chat, release: share.release, user: user }
      Review.find_by(attributes) || Review.create_or_find_by!(attributes)
    end

    def find_or_create_message(review, share, text)
      attributes = { release_share: share, telegram_message_id: @message[:message_id] }
      ReviewMessage.find_by(attributes) ||
        ReviewMessage.create_or_find_by!(attributes) do |review_message|
          review_message.review = review
          review_message.source = :text
          review_message.text = text
          review_message.sent_at = Time.zone.at(@message[:date])
        end
    end

    def user
      @user ||= ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
    end
  end
end
