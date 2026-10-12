class ScoreReviewJob < ApplicationJob
  queue_as :default

  # One run per review at a time (enforced by Solid Queue, not the test
  # adapter): a run reads all messages when it starts, so two in parallel
  # could let the one that read fewer messages write last.
  limits_concurrency key: ->(review) { review }, duration: 5.minutes

  retry_on OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::InternalServerError,
    OpenAI::Errors::RateLimitError,
    wait: :polynomially_longer,
    attempts: 5

  discard_on ActiveJob::DeserializationError

  def perform(review)
    Camerton::ReviewScoring.new(review).call
  end
end
