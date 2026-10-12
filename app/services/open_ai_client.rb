class OpenAiClient
  # A missing OPENAI_API_KEY raises here instead of failing later with a 401.
  def self.build
    OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
  end
end
