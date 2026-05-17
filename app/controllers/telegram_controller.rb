require "telegram/bot"

class TelegramController < ApplicationController
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
end
