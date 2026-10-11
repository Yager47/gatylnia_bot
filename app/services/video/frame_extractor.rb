module Video
  class FrameExtractor
    # Writes `count` frames into `dir`, taken at the midpoints of equal slices
    # of the video, so the often black or shaky first and last frames are
    # skipped. Returns the paths that were written; the caller owns `dir`.
    def self.call(video_path, dir:, count:, duration:)
      return [] unless ffmpeg_available?

      seconds = duration.to_f.positive? ? duration.to_f : 1.0
      count.times.filter_map do |index|
        at = (seconds * (index + 0.5) / count).round(2)
        output = File.join(dir, format("frame_%02d.jpg", index))
        system("ffmpeg", "-y", "-ss", at.to_s, "-i", video_path, "-frames:v", "1", "-vf", "scale=384:-1", "-q:v", "5", output,
               out: File::NULL, err: File::NULL)

        output if File.exist?(output)
      end
    rescue StandardError
      []
    end

    def self.ffmpeg_available?
      system("which ffmpeg > /dev/null 2>&1")
    end
  end
end
