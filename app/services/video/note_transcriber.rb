module Video
  class NoteTranscriber
    def self.call(file_path)
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      response = client.audio.transcriptions.create(
        model: "whisper-1",
        file: File.open(file_path)
      )

      extract_text(response)
    end

    def self.extract_text(response)
      if response.respond_to?(:text)
        response.text
      else
        payload = response.is_a?(Hash) ? response : response.to_h
        payload.dig("text")
      end
    end
  end
end
