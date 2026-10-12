require "telegram/bot"

module Camerton
  # The bot's emoji on a review's latest message, so the reviewer sees it was
  # counted and how it was read. A reply that isn't a review clears it.
  # Cosmetic: a failure (the chat may not allow the emoji) is logged, not
  # retried, so it never costs another scoring call.
  class ReviewReaction
    EMOJIS = { bad: "🤬", mid: "🤔", good: "👍", great: "🔥" }.freeze

    def initialize(review, client: TelegramClient.build)
      @review = review
      @client = client
    end

    def call
      message = @review.messages.order(:sent_at, :id).last
      return unless message

      @client.api.set_message_reaction(
        chat_id: @review.chat.telegram_id,
        message_id: message.telegram_message_id,
        reaction: reaction
      )
    rescue Telegram::Bot::Exceptions::ResponseError, Faraday::Error => e
      Rails.logger.warn("[Camerton::ReviewReaction] Review #{@review.id}: #{e.class}: #{e.message}")
    end

    private

    def reaction
      label = @review.label
      label ? [ Telegram::Bot::Types::ReactionTypeEmoji.new(type: "emoji", emoji: EMOJIS.fetch(label)) ] : []
    end
  end
end
