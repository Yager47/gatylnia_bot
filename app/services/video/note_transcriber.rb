module Video
  class NoteTranscriber
    MODEL = "whisper-1".freeze
    LANGUAGE = "uk".freeze

    # With the default JSON response format the result is an
    # OpenAI::Audio::Transcription, which always has #text.
    def self.call(file_path)
      File.open(file_path) do |file|
        OpenAiClient.build.audio.transcriptions.create(model: MODEL, file: file, language: LANGUAGE).text
      end
    end
  end
end
