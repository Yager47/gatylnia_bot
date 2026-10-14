module Notes
  # Stores one reply as a note on a track and marks it with the bot's
  # reaction. Writing the same text again is a no-op (a redelivery);
  # different text replaces it (an edit), keeping the reaction already there.
  class NoteWriter
    def initialize(track:, user:)
      @track = track
      @user = user
    end

    def write(telegram_message_id:, source:, text:, sent_at:)
      note = @track.notes.find_by(telegram_message_id: telegram_message_id) ||
        @track.notes.create_or_find_by!(telegram_message_id: telegram_message_id) do |new_note|
          new_note.user = @user
          new_note.source = source
          new_note.text = text
          new_note.sent_at = sent_at
        end
      if note.previously_new_record?
        NoteReaction.new(note).call
      elsif note.text != text
        note.update!(text: text)
      end
      note
    end
  end
end
