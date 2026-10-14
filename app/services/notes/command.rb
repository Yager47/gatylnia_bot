module Notes
  # The notes commands in chats with notes on. In reply to a track:
  # "замітки" (everyone's), "замітки @нік" (one person's), "мої замітки" and
  # "видали замітки" (removes the sender's own notes on that track). On its
  # own: "останнє аудіо" or "аудіо" points at the latest track.
  class Command
    USER_NOTES = /\Aзамітки @(\w+)\z/
    LAST_AUDIO = [ "останнє аудіо", "аудіо" ].freeze
    HERE_IT_IS = "осьо".freeze

    def initialize(command:, chat:, user:, reply_to_message:)
      @command = command.strip
      @chat = chat
      @user = user
      @reply_to_message = reply_to_message
    end

    # Returns the reply text (a Response::Threaded for the latest track), or
    # nil when the command isn't about notes. Expects the command already
    # lowercased, without the bot mention.
    def call
      return unless @chat.notes_enabled?

      if (match = USER_NOTES.match(@command))
        user_notes(match[1])
      elsif LAST_AUDIO.include?(@command)
        last_audio
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

    # Telegram numbers a chat's messages in order, and the unique index on
    # (chat_id, telegram_message_id) serves this without a sort.
    def last_audio
      track = @chat.audio_tracks.order(telegram_message_id: :desc).first
      return "Тут ще нема аудіо." unless track

      Response::Threaded.new(text: HERE_IT_IS, reply_to: track.telegram_message_id)
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
