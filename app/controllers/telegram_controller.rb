require "telegram/bot"

class TelegramController < ApplicationController
  SECRET_TOKEN_HEADER = "X-Telegram-Bot-Api-Secret-Token".freeze

  before_action :verify_secret_token

  def webhook
    update_id = Integer(params.expect(:update_id), exception: false)
    return head :bad_request unless update_id

    TelegramUpdates::Ingest.new(update_id: update_id, payload: payload).call
    head :ok
  end

  private

  # The raw update exactly as Telegram sent it. It is only stored as JSON and
  # never mass-assigned, so it isn't filtered through strong parameters; the
  # one field we act on (update_id) is read via params.expect above.
  def payload
    JSON.parse(request.raw_post)
  end

  def verify_secret_token
    expected = ENV["TELEGRAM_WEBHOOK_SECRET"]

    if expected.blank?
      Rails.logger.error("[TelegramController] TELEGRAM_WEBHOOK_SECRET is not set, rejecting webhook request")
      head :unauthorized
    elsif !ActiveSupport::SecurityUtils.secure_compare(request.headers[SECRET_TOKEN_HEADER].to_s, expected)
      Rails.logger.warn("[TelegramController] Rejected webhook request with missing or invalid secret token")
      head :unauthorized
    end
  end
end
