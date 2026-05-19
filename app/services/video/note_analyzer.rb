module Video
  class NoteAnalyzer
    Result = Struct.new(:description, :frame_path)

    def self.call(video_note:, user:)
      path = TelegramFileDownloader.download(video_note[:file_id])
      transcript = NoteTranscriber.call(path)
      frame_path = FrameExtractor.call(path)
      description = build_description(user, video_note[:duration], transcript)

      Result.new(description: description, frame_path: frame_path)
    rescue StandardError => e
      Rails.logger.error("[Video::NoteAnalyzer] #{e.class}: #{e.message}")
      Result.new(description: fallback_description(user, video_note[:duration]), frame_path: nil)
    ensure
      cleanup(path)
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

    def self.cleanup(path)
      return unless path

      File.delete(path) if File.exist?(path)
    end
  end
end
