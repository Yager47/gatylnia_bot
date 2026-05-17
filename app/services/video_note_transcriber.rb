class VideoNoteTranscriber
  def self.call(file_path)
    client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

    File.open(file_path, "rb") do |file|
      response = client.audio.transcriptions.create(
        model: "whisper-1",
        file: file,
        language: "uk"
      )

      extract_text(response).to_s.strip
    end
  end

  def self.extract_text(response)
    return response if response.is_a?(String)

    payload = response.is_a?(Hash) ? response : response.to_h
    payload["text"] || payload[:text]
  end
  private_class_method :extract_text
end
