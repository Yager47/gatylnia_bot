require "test_helper"

class VideoNoteAnalyzerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @video_note = { file_id: "file123", duration: 7 }
    @tempfile = Tempfile.new(["video", ".mp4"])
    @tempfile.write("fake")
    @tempfile.close
  end

  teardown do
    @tempfile.unlink
  end

  test "builds description from transcript" do
    TelegramFileDownloader.stub(:download, @tempfile.path) do
      VideoNoteTranscriber.stub(:call, "привіт друзі") do
        VideoFrameExtractor.stub(:call, nil) do
          result = VideoNoteAnalyzer.call(video_note: @video_note, user: @user)

          assert_includes result.description, "кружочек (7с)"
          assert_includes result.description, "привіт друзі"
          assert_nil result.frame_path
        end
      end
    end
  end

  test "falls back when download fails" do
    TelegramFileDownloader.stub(:download, ->(*) { raise "network error" }) do
      result = VideoNoteAnalyzer.call(video_note: @video_note, user: @user)

      assert_includes result.description, "кружочек (7с)"
      assert_nil result.frame_path
    end
  end
end
