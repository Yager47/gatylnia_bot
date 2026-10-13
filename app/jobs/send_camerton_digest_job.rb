# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

class SendCamertonDigestJob < ApplicationJob
  queue_as :default

  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  # Safe to run twice: the digest records the day it was sent.
  def perform(chat)
    Camerton::ReminderDigest.new(chat).deliver
  end
end
