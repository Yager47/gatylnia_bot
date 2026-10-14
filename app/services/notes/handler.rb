module Notes
  # The notes part of a message in a chat with notes on, run before the mode
  # handler: audio becomes a track, and a direct reply to it becomes a note.
  class Handler
    def initialize(message:, chat:)
      @message = message
      @chat = chat
    end

    # Returns what the message was to notes: :track, :note or nil. Either way
    # the mode handler stays quiet about it.
    def call
      return :track if Audio.in(@message) && TrackRecorder.new(chat: @chat).record(@message)

      :note if record_note
    end

    private

    def record_note
      return if text.blank? || bot_command?

      track = TrackRecorder.new(chat: @chat).record(@message[:reply_to_message])
      return unless track

      NoteWriter.new(track: track, user: user)
        .write(telegram_message_id: @message[:message_id], source: :text, text: text, sent_at: Time.zone.at(@message[:date]))
    end

    def text
      @message[:text] || @message[:caption]
    end

    # "@bot замітки" in reply to a track asks for its notes; it isn't one.
    def bot_command?
      text.downcase.start_with?(BotMention.text)
    end

    def user
      ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
    end
  end
end
