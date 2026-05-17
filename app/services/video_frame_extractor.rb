class VideoFrameExtractor
  def self.call(video_path)
    return nil unless ffmpeg_available?

    output = Tempfile.new(["video_frame", ".jpg"])
    output.close

    success = system(
      "ffmpeg", "-y", "-loglevel", "error",
      "-i", video_path,
      "-ss", "00:00:01",
      "-vframes", "1",
      output.path,
      out: File::NULL
    )

    return output.path if success && File.exist?(output.path) && File.size(output.path).positive?

    File.delete(output.path)
    nil
  end

  def self.ffmpeg_available?
    system("which", "ffmpeg", out: File::NULL, err: File::NULL)
  end
  private_class_method :ffmpeg_available?
end
