class Ai
  CONTEXT_LIMIT = 20

  class << self
    def reply_in(chat, vision_frame_path: nil)
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      response = client.chat.completions.create(
        model: "gpt-5-mini",
        messages: messages(chat, vision_frame_path: vision_frame_path)
      )

      response[:choices][0][:message][:content]
    end

    private

    def messages(chat, vision_frame_path:)
      result = [
        { role: "system", content: prompt },
        { role: "system", content: examples }
      ]

      history = chat.messages
                    .includes(:user, :reply_to)
                    .order(:created_at)
                    .last(CONTEXT_LIMIT)

      history.each_with_index do |message, index|
        content = message.ai_context
        last_user_message = index == history.length - 1 && message.role == "user"

        if last_user_message && vision_frame_path.present?
          result << vision_message(content, vision_frame_path)
        else
          result << { role: message.role, content: content }
        end
      end

      result
    end

    def vision_message(text, frame_path)
      {
        role: "user",
        content: [
          { type: "text", text: text },
          {
            type: "image_url",
            image_url: { url: "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(frame_path))}" }
          }
        ]
      }
    end

    def prompt
      File.read Rails.root.join("lib/ai_prompt/v2.txt")
    end

    def examples
      "А ще, ось додаткові фрази для глибшого розуміння нашого сленгу та вайбу, може бути корисним (ігноруй де є rhythm): " \
        "#{File.read(Rails.root.join('lib/answers/chance.yml.erb'))}"
    end
  end
end
