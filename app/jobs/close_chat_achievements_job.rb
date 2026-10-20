# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

class CloseChatAchievementsJob < ApplicationJob
  queue_as :default

  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  # Safe to run twice: the second run finds the period's achievements
  # already stored and announces nothing.
  def perform(chat, kind)
    Achievements::Closer.new(chat, kind.to_sym).call
  end
end
