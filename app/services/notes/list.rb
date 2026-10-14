module Notes
  # The notes on the track a command replied to, grouped by person in the
  # order they first wrote, each person's notes in the order sent. Two
  # queries however many notes. Long lists are split into several messages
  # by ChatMessenger.
  class List
    SOURCE_MARKS = { "voice" => "🎤 ", "video_note" => "⭕ " }.freeze
    NOT_A_TRACK = "Відповідай цією командою на аудіо з треком.".freeze

    # reply_to_message: the Telegram message the command replied to, if any.
    # author: only this person's notes.
    def initialize(chat:, reply_to_message:, author: nil)
      @chat = chat
      @reply_to_message = reply_to_message
      @author = author
    end

    def text
      return NOT_A_TRACK unless Audio.in(@reply_to_message)

      track = @chat.audio_tracks.find_by(telegram_message_id: @reply_to_message[:message_id])
      notes = track ? scope(track).includes(:user).order(:sent_at, :id).to_a : []
      return empty_text if notes.empty?

      [ "📝 Замітки до «#{track.label}»:", *notes.group_by(&:user).map { |user, user_notes| block(user, user_notes) } ].join("\n\n")
    end

    private

    def scope(track)
      @author ? track.notes.where(user: @author) : track.notes
    end

    def empty_text
      return "До цього треку ще нема заміток." unless @author

      "#{@author.name}: заміток до цього треку нема."
    end

    def block(user, notes)
      [ "#{user.name}:", *notes.map { |note| "• #{SOURCE_MARKS[note.source]}#{note.text.strip}" } ].join("\n")
    end
  end
end
