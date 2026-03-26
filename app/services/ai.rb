class Ai
  class << self
    def reply_in(chat)
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      response = client.chat.completions.create(
        model: "gpt-5-mini",
        messages: messages(chat)
      )

      response[:choices][0][:message][:content]
    end

    private

    def messages(chat)
      result = [
        { role: "system", content: prompt },
        { role: "system", content: examples }
      ]

      chat.messages.last(20).each do |message|
        result << { role: message.role, content: content(message) }
      end

      result
    end

    def prompt
      File.read Rails.root.join("lib/ai_prompt/v2.txt")
    end

    def examples
      "А ще, ось додаткові фрази для глибшого розуміння нашого сленгу та вайбу, може бути корисним (ігноруй де є rhythm): " \
        "#{File.read(Rails.root.join('lib/answers/chance.yml.erb'))}"
    end

    def content(message)
      user_name = message.role == "user" ? "#{message.user.name}: " : ""
      "#{user_name}\"#{message.content}\""
    end
  end
end