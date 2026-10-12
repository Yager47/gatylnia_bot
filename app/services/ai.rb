class Ai
  CONTEXT_LIMIT = 20

  class << self
    # frames_for: the video note message the frames belong to. They're attached
    # to that message, not to whatever was said last, and the reply is aimed
    # at it even if others wrote in the meantime.
    def reply_in(chat, frames_for: nil, frame_paths: [])
      client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])

      response = client.chat.completions.create(
        model: "gpt-5-mini",
        messages: messages(chat, frames_for: frames_for, frame_paths: frame_paths)
      )

      response[:choices][0][:message][:content]
    end

    private

    def messages(chat, frames_for:, frame_paths:)
      result = [
        { role: "system", content: prompt },
        { role: "system", content: examples }
      ]

      history = chat.messages
                    .includes(:user, :reply_to)
                    .order(:created_at)
                    .last(CONTEXT_LIMIT)

      history.each do |message|
        if frame_paths.any? && message.id == frames_for&.id
          result << vision_message(message.ai_context, frame_paths)
        else
          result << { role: message.role, content: message.ai_context }
        end
      end

      result << { role: "system", content: video_target(frames_for) } if frames_for
      result
    end

    def vision_message(text, frame_paths)
      images = frame_paths.map do |path|
        { type: "image_url", image_url: { url: "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(path))}", detail: "low" } }
      end

      {
        role: "user",
        content: [ { type: "text", text: "#{text}\nКадри з цього відео, по порядку:" }, *images ]
      }
    end

    def video_target(message)
      "Зараз відповідай саме на відео від #{message.user&.name || 'когось'}, а не на інші повідомлення."
    end

    def prompt
      AnswerFiles.text("lib/ai_prompt/v2.txt")
    end

    def examples
      "А ще, ось додаткові фрази для глибшого розуміння нашого сленгу та вайбу, може бути корисним (ігноруй де є rhythm): " \
        "#{AnswerFiles.text('lib/answers/chance.yml.erb')}"
    end
  end
end
