require "telegram/bot"

module Video
  class NoteAnalyzer
    FRAMES = 6

    # Failures of Telegram, OpenAI or the network. Anything else is a bug in
    # our code and should raise, not turn into "couldn't process the video".
    SERVICE_ERRORS = [
      TelegramFileDownloader::Error,
      Telegram::Bot::Exceptions::Base,
      Faraday::Error,
      OpenAI::Errors::Error,
      SocketError,
      SystemCallError,
      Timeout::Error,
      OpenSSL::SSL::SSLError
    ].freeze

    Result = Struct.new(:description, :transcript, :frame_paths)

    # The video and its frames are written into `dir`, which the caller
    # creates and removes.
    def self.call(video_note:, user:, dir:)
      path = TelegramFileDownloader.download(video_note[:file_id], dir: dir)
      transcript = NoteTranscriber.call(path)
      frame_paths = FrameExtractor.call(path, dir: dir, count: FRAMES, duration: video_note[:duration])
      description = build_description(user, video_note[:duration], transcript)

      Result.new(description: description, transcript: transcript, frame_paths: frame_paths)
    rescue *SERVICE_ERRORS => e
      Rails.logger.error("[Video::NoteAnalyzer] #{e.class}: #{e.message}")
      Rails.error.report(e, handled: true)
      Result.new(description: fallback_description(user, video_note[:duration]), transcript: nil, frame_paths: [])
    end

    def self.build_description(user, duration, transcript)
      description = "#{author(user)} записав відео #{duration}s."
      description += " Транскрипт: #{transcript}." if transcript.present?
      description
    end

    def self.fallback_description(user, duration)
      "#{author(user)} надіслав відео #{duration}s, але не вдалося обробити його вміст."
    end

    def self.author(user)
      user&.name || "хтось"
    end
    private_class_method :fallback_description, :author
  end
end
