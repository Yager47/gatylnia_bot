require "telegram/bot"

class TelegramController < ApplicationController
  SECRET_TOKEN_HEADER = "X-Telegram-Bot-Api-Secret-Token".freeze

  before_action :verify_secret_token

  def webhook
    if params[:message_reaction].present?
      MessageReactionHandler.new(params[:message_reaction]).call
    elsif params[:message_reaction_count].present?
      MessageReactionHandler.new(params[:message_reaction_count], count_mode: true).call
    elsif params[:message] && params[:message][:new_chat_title].present?
      NewChatTitle.new(params[:message]).call
    elsif message.present?
      MessageHandler.new(message).call
    end

    head :ok
  end

  private

  def message
    params[:message] || params[:edited_message]
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
