require 'telegram/bot'

class TelegramController < ApplicationController
  def webhook
    if params[:message] && params[:message][:new_chat_title].present?
      NewChatTitle.new(params[:message]).call
    else
      MessageHandler.new(message).call
    end

    head :ok
  end

  private

  def message
    params[:message] || params[:edited_message]
  end
end
