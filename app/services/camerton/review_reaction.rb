require "telegram/bot"

module Camerton
  # The bot's emoji on a review's latest message, so the reviewer sees it was
  # counted and how it was read. A review without a written score gets ✍
  # (noted, no score); a reply that isn't a review clears it.
  # Cosmetic: a failure (the chat may not allow the emoji) is logged, not
  # retried, so it never costs another scoring call.
  class ReviewReaction
    EMOJIS = { bad: "🤬", mid: "🤔", good: "👍", great: "🔥" }.freeze
    # Without the variation selector: Telegram's reaction list has it bare.
    UNSCORED_EMOJI = "✍".freeze

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
      log(e)
    end

    # Takes the bot's emoji off every message of the review (each one got
    # it while it was the latest), before the review is removed.
    def clear
      @review.messages.each do |message|
        @client.api.set_message_reaction(chat_id: @review.chat.telegram_id, message_id: message.telegram_message_id, reaction: [])
      rescue Telegram::Bot::Exceptions::ResponseError, Faraday::Error => e
        log(e)
      end
    end

    private

    def log(error)
      Rails.logger.warn("[Camerton::ReviewReaction] Review #{@review.id}: #{error.class}: #{error.message}")
    end

    # Only a review has a summary (ReviewScoring), so one without a score is
    # a review whose author wrote no score.
    def reaction
      emoji = if @review.label
        EMOJIS.fetch(@review.label)
      elsif @review.summary.present?
        UNSCORED_EMOJI
      end
      emoji ? [ Telegram::Bot::Types::ReactionTypeEmoji.new(type: "emoji", emoji: emoji) ] : []
    end
  end
end
