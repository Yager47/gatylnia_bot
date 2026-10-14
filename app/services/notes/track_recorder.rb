module Notes
  # Finds or creates the AudioTrack for a Telegram message with audio. Used
  # for new audio messages and for the message a note replies to, so audio
  # sent before notes were turned on is picked up by its first note. Safe to
  # run twice (unique index, create_or_find_by!).
  class TrackRecorder
    def initialize(chat:)
      @chat = chat
    end

    # Returns the track, or nil when the message has no audio or no person
    # sent it.
    def record(message)
      audio = Audio.in(message)
      return if audio.nil? || message[:from].blank? || message[:sender_chat].present?

      @chat.audio_tracks.find_by(telegram_message_id: message[:message_id]) ||
        @chat.audio_tracks.create_or_find_by!(telegram_message_id: message[:message_id]) do |track|
          track.user = ChatMembers::Resolver.new(chat: @chat, from: message[:from]).call
          track.title = audio[:title]
          track.performer = audio[:performer]
          track.file_name = audio[:file_name]
          track.duration = audio[:duration]
          track.caption = message[:caption]
          track.sent_at = Time.zone.at(message[:date])
        end
    end
  end
end
