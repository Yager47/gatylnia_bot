module TelegramUpdates
  # Routes an update payload to its handler. Returns false for update types
  # the bot doesn't handle.
  class Dispatcher
    def initialize(payload)
      @update = payload.with_indifferent_access
    end

    def call
      if @update[:message_reaction].present?
        MessageReactionHandler.new(@update[:message_reaction]).call
      elsif @update[:message_reaction_count].present?
        MessageReactionHandler.new(@update[:message_reaction_count], count_mode: true).call
      elsif @update[:message] && @update[:message][:new_chat_title].present?
        NewChatTitle.new(@update[:message]).call
      elsif message.present?
        MessageHandler.new(message).call
      else
        return false
      end

      true
    end

    private

    def message
      @update[:message] || @update[:edited_message]
    end
  end
end
