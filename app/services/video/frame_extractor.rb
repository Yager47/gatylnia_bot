require "shellwords"

module Video
  class FrameExtractor
    def self.call(video_path)
      return unless ffmpeg_available?

      output = Tempfile.new([ "video_frame", ".jpg" ])
      output.binmode
      output.close

      system("ffmpeg -y -i #{Shellwords.escape(video_path)} -frames:v 1 #{Shellwords.escape(output.path)} > /dev/null 2>&1")

      output.path if File.exist?(output.path)
    rescue StandardError => _e
      nil
    end

    def self.ffmpeg_available?
      system("which ffmpeg > /dev/null 2>&1")
    end
  end
end
