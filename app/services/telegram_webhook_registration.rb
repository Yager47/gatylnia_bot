class TelegramWebhookRegistration
  ALLOWED_UPDATES = %w[
    message
    edited_message
    message_reaction
    message_reaction_count
  ].freeze

  # Telegram allows 1-256 chars of A-Z, a-z, 0-9, _ and -; we require at least 32.
  SECRET_TOKEN_FORMAT = /\A[A-Za-z0-9_-]{32,256}\z/

  def initialize(url:, secret_token:, client: TelegramClient.build)
    unless SECRET_TOKEN_FORMAT.match?(secret_token.to_s)
      raise ArgumentError, "secret_token must be 32-256 characters of A-Z, a-z, 0-9, _ or -"
    end

    @url = url
    @secret_token = secret_token
    @client = client
  end

  def register
    @client.api.set_webhook(url: @url, secret_token: @secret_token, allowed_updates: ALLOWED_UPDATES)
  end

  def reset
    @client.api.delete_webhook(drop_pending_updates: true)
    register
  end
end
