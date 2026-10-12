# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

class TrackCoffeeTextJob < ApplicationJob
  queue_as :default

  # The default handler sends coffee candidates here without replying, so a
  # message that turns out not to be coffee gets the reply it would have got.
  IN_CHARACTER_REPLY_CHANCE = 0.8

  retry_on OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::InternalServerError,
    OpenAI::Errors::RateLimitError,
    Faraday::ConnectionFailed,
    Faraday::TimeoutError,
    wait: :polynomially_longer,
    attempts: 3

  discard_on ActiveJob::DeserializationError

  def perform(message, sent_at:)
    @message = message
    @chat = message.chat
    @user = message.user

    # A retry after the coffee was recorded: don't pay for the model again.
    return if @chat.activities.coffee.exists?(telegram_message_id: message.telegram_message_id)

    verdict = Activities::CoffeeTextClassifier.new.call(message.content)

    if verdict.coffee
      record_and_confirm(verdict, sent_at)
    elsif bot_mentioned? || rand < IN_CHARACTER_REPLY_CHANCE
      reply_in_character
    end
  end

  private

  # Record and send in one transaction: if sending fails, the record rolls
  # back and a retry starts clean. If the send succeeds but the commit fails,
  # a retry sends the confirmation again; that rare case is accepted.
  def record_and_confirm(verdict, sent_at)
    Activity.transaction do
      recorded = Activities::Recorder.new(
        user: @user, chat: @chat, kind: :coffee, source: :text,
        telegram_message_id: @message.telegram_message_id, occurred_at: sent_at,
        details: { "ordinal" => verdict.ordinal }.compact
      ).call
      next unless recorded

      deliver(Activities::Confirmation.new(user: @user, chat: @chat, day: sent_at).text(coffee: 1))
    end
  end

  def reply_in_character
    text = Response::Ai.new(chat: @chat).call
    deliver(text) if text.is_a?(String)
  end

  def deliver(text)
    reply = @chat.messages.create!(role: :assistant, content: text)
    ChatMessenger.new(chat: @chat).deliver(reply)
  end

  def bot_mentioned?
    @message.content.downcase.include?(BotMention.text)
  end
end
