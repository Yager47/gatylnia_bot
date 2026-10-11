module TelegramUpdates
  # Routes an update payload to its handler. Returns false for updates the
  # bot doesn't handle: unsupported types and anything outside group chats.
  class Dispatcher
    COMMANDS = { "ping" => Commands::Ping }.freeze
    GROUP_CHAT_TYPES = %w[group supergroup].freeze

    def initialize(payload)
      @update = payload.with_indifferent_access
    end

    def call
      return false unless group_chat?

      if @update[:message_reaction].present?
        MessageReactionHandler.new(@update[:message_reaction]).call
      elsif @update[:message_reaction_count].present?
        MessageReactionHandler.new(@update[:message_reaction_count], count_mode: true).call
      elsif @update[:message] && @update[:message][:new_chat_title].present?
        NewChatTitle.new(@update[:message]).call
      elsif command
        reply_to_command
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

    def group_chat?
      source = message || @update[:message_reaction] || @update[:message_reaction_count]
      GROUP_CHAT_TYPES.include?(source&.dig(:chat, :type))
    end

    # Only new messages: an edited "/ping" doesn't reply again.
    def command
      return unless @update[:message]

      @command ||= COMMANDS[Command.parse(@update[:message])]
    end

    def reply_to_command
      TelegramClient.build.api.send_message(chat_id: @update[:message][:chat][:id], text: command.new.call)
    end
  end
end
