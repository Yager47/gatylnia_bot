class Ai
  class << self
    def reply_to(message)
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      response = client.chat.completions.create(
        model: "gpt-5-mini",
        messages: [
          { role: "system", content: prompt },
          { role: "system", content: examples },
          { role: "user",   content: message }
        ]
      )

      response[:choices][0][:message][:content]
    end

    private

    def prompt
      File.read Rails.root.join("lib/ai_prompt.txt")
    end

    def examples
      "Деякі приклади відповідей (ігноруй де є rhythm): " \
        "#{File.read(Rails.root.join('lib/answers/chance.yml.erb'))}"
    end
  end
end