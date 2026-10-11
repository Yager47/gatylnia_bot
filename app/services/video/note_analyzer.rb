module Video
  class NoteAnalyzer
    FRAMES = 6

    Result = Struct.new(:description, :transcript, :frame_paths)

    # The video and its frames are written into `dir`, which the caller
    # creates and removes.
    def self.call(video_note:, user:, dir:)
      path = TelegramFileDownloader.download(video_note[:file_id], dir: dir)
      transcript = NoteTranscriber.call(path)
      frame_paths = FrameExtractor.call(path, dir: dir, count: FRAMES, duration: video_note[:duration])
      description = build_description(user, video_note[:duration], transcript)

      Result.new(description: description, transcript: transcript, frame_paths: frame_paths)
    rescue StandardError => e
      Rails.logger.error("[Video::NoteAnalyzer] #{e.class}: #{e.message}")
      Result.new(description: fallback_description(user, video_note[:duration]), transcript: nil, frame_paths: [])
    end

    def self.build_description(user, duration, transcript)
      duration_text = "#{duration}s"
      user_name = user&.name || "хтось"

      description = "#{user_name} записав відео #{duration_text}."
      description += " Транскрипт: #{transcript}." if transcript.present?
      description
    end

    def self.fallback_description(user, duration)
      duration_text = "#{duration}s"
      user_name = user&.name || "хтось"

      "#{user_name} надіслав відео #{duration_text}, але не вдалося обробити його вміст."
    end
  end
end
