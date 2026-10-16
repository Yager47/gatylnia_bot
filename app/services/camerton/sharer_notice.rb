require "telegram/bot"

module Camerton
  # Tells whoever shared a release that it got a score, as a reply to the
  # review's latest message: "@olya, твій реліз оцінили на 7/10 👍". Every
  # member who shared it in this chat is mentioned, except the reviewer.
  # Cosmetic like ReviewReaction: a failure is logged, not retried, so it
  # never costs another scoring call.
  class SharerNotice
    def initialize(review)
      @review = review
      @chat = review.chat
    end

    # The transaction rolls back the assistant message if sending fails.
    def call
      return unless @review.score

      message = @review.messages.order(:sent_at, :id).last
      return unless message

      body = text
      return unless body

      Message.transaction do
        reply = @chat.messages.create!(role: :assistant, content: body)
        ChatMessenger.new(chat: @chat).deliver(reply, reply_to: message.telegram_message_id, parse_mode: "HTML")
      end
    rescue Telegram::Bot::Exceptions::ResponseError, Faraday::Error => e
      Rails.logger.warn("[Camerton::SharerNotice] Review #{@review.id}: #{e.class}: #{e.message}")
    end

    # HTML for Telegram, or nil when the reviewer is the only sharer.
    def text
      mentions = sharers.map { |user| Formatting.mention(user) }
      return if mentions.empty?

      yours = mentions.one? ? "твій" : "ваш"
      emoji = ReviewReaction::EMOJIS.fetch(@review.label)

      "#{mentions.join(', ')}, #{yours} реліз оцінили на #{@review.score}/10 #{emoji}"
    end

    private

    def sharers
      shares = ReleaseShare.where(chat_id: @review.chat_id, release_id: @review.release_id)
      User.where(id: shares.select(:user_id)).where.not(id: @review.user_id).order(:id)
    end
  end
end
