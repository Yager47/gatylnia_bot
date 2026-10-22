# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

class SendPointsSummaryJob < ApplicationJob
  queue_as :default

  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  # Safe to run twice: the summary records the Monday it was sent.
  def perform(chat)
    Zhmykhcoins::WeeklySummary.new(chat).deliver
  end
end
