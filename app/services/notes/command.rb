module Notes
  # The notes commands, each in reply to a track, in chats with notes on:
  # "замітки" (everyone's), "замітки @нік" (one person's), "мої замітки" and
  # "видали замітки" (removes the sender's own notes on that track).
  class Command
    USER_NOTES = /\Aзамітки @(\w+)\z/

    def initialize(command:, chat:, user:, reply_to_message:)
      @command = command.strip
      @chat = chat
      @user = user
      @reply_to_message = reply_to_message
    end

    # Returns the reply text, or nil when the command isn't about notes.
    # Expects the command already lowercased, without the bot mention.
    def call
      return unless @chat.notes_enabled?

      if (match = USER_NOTES.match(@command))
        user_notes(match[1])
      else
        case @command
        when "замітки" then list.text
        when "мої замітки" then list(author: @user).text
        when "видали замітки" then remove
        end
      end
    end

    private

    def list(author: nil)
      List.new(chat: @chat, reply_to_message: @reply_to_message, author: author)
    end

    def user_notes(username)
      author = @chat.users.find_by("LOWER(users.username) = ?", username)
      return "Не знайшов @#{username} у цьому чаті." unless author

      list(author: author).text
    end

    def remove
      return List::NOT_A_TRACK unless Audio.in(@reply_to_message)

      track = @chat.audio_tracks.find_by(telegram_message_id: @reply_to_message[:message_id])
      removed = track ? track.notes.where(user: @user).delete_all : 0
      return "У тебе нема заміток до цього треку." if removed.zero?

      "Видалив твої замітки до «#{track.label}» (#{removed})."
    end
  end
end
