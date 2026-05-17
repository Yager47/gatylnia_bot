class VideoNoteAnalyzer
  Result = Data.define(:description, :frame_path)

  def self.call(video_note:, user:)
    path = TelegramFileDownloader.download(video_note[:file_id])
    frame_path = nil

    begin
      transcript = VideoNoteTranscriber.call(path)
      frame_path = VideoFrameExtractor.call(path)
      description = build_description(user, video_note[:duration], transcript)

      Result.new(description: description, frame_path: frame_path)
    rescue StandardError => e
      Rails.logger.error("[VideoNoteAnalyzer] #{e.class}: #{e.message}")
      cleanup(frame_path)
      Result.new(description: fallback_description(user, video_note[:duration]), frame_path: nil)
    ensure
      File.delete(path) if path && File.exist?(path)
    end
  end

  def self.build_description(user, duration, transcript)
    seconds = duration.to_i

    if transcript.present?
      "#{user.name} надіслав кружочек (#{seconds}с): «#{transcript}»"
    else
      "#{user.name} надіслав кружочек (#{seconds}с) — без розбірливої мови, відповідай по вайбу"
    end
  end
  private_class_method :build_description

  def self.fallback_description(user, duration)
    "#{user.name} надіслав кружочек (#{duration.to_i}с)"
  end
  private_class_method :fallback_description

  def self.cleanup(path)
    File.delete(path) if path && File.exist?(path)
  end
  private_class_method :cleanup
end
