# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

class AnnounceReleaseJob < ApplicationJob
  queue_as :default

  # A release still pending after the last attempt stays pending and its share
  # unannounced; sharing it again starts a new lookup.
  retry_on Camerton::YoutubeOembed::TransientError,
    OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::InternalServerError,
    OpenAI::Errors::RateLimitError,
    Faraday::ConnectionFailed,
    Faraday::TimeoutError,
    wait: :polynomially_longer,
    attempts: 5

  discard_on ActiveJob::DeserializationError

  def perform(share)
    Camerton::ReleaseResolver.new(share.release).call
    share.reload # the release may have been merged into another one
    Camerton::DiscogsDetails.new(share.release).call
    Camerton::ShareAnnouncement.new(share).deliver
  end
end
