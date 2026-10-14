module Notes
  # The audio file in a Telegram message, if any: a track sent as audio (the
  # music player), or a file such as a wav or flac that Telegram delivers as
  # a document with an audio MIME type.
  module Audio
    def self.in(message)
      return if message.blank?
      return message[:audio] if message[:audio].present?

      document = message[:document]
      document if document.present? && document[:mime_type].to_s.start_with?("audio/")
    end
  end
end
