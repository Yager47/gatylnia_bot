# Looks up a release's names without announcing anything (history imports;
# live shares go through AnnounceReleaseJob).
class ResolveReleaseJob < ApplicationJob
  queue_as :default

  retry_on Camerton::YoutubeOembed::TransientError,
    OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::InternalServerError,
    OpenAI::Errors::RateLimitError,
    wait: :polynomially_longer,
    attempts: 5

  discard_on ActiveJob::DeserializationError

  def perform(release)
    Camerton::ReleaseResolver.new(release).call
  end
end
