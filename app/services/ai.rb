class Ai
  CONTEXT_LIMIT = 20
  # What the model answers when a message isn't for it and it has nothing to add.
  SKIP = "SKIP".freeze
  # How many of its own latest replies the model is told not to repeat.
  RECENT_REPLIES = 3

  class << self
    # target: the message being answered. The model is told which one it is
    # and whom it's addressed to, instead of guessing from the history.
    # frame_paths: a video note's frames, attached to the target message.
    # note: what to do with the target, instead of judging whom it's for.
    def reply_in(chat, target: nil, frame_paths: [], note: nil)
      response = OpenAiClient.build.chat.completions.create(
        model: "gpt-5-mini",
        verbosity: :low,
        messages: messages(chat, target: target, frame_paths: frame_paths, note: note)
      )

      response.choices.first.message.content
    end

    # Tolerates the model adding punctuation or spaces around the word.
    def skip?(text)
      text.to_s.strip.match?(/\A#{SKIP}\W*\z/i)
    end

    private

    def messages(chat, target:, frame_paths:, note: nil)
      result = [
        { role: "system", content: prompt },
        { role: "system", content: examples }
      ]

      history = chat.messages
                    .includes(:user, :reply_to)
                    .order(:created_at)
                    .last(CONTEXT_LIMIT)

      history.each do |message|
        if frame_paths.any? && message.id == target&.id
          result << vision_message(message.ai_context, frame_paths)
        else
          result << { role: message.role, content: message.ai_context }
        end
      end

      recent_replies = history.select(&:assistant?).last(RECENT_REPLIES).map(&:content)
      result << { role: "system", content: target_note(target, note, recent_replies) } if target
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

    # A mention or a reply to the bot must be answered; anything else may be
    # people talking to each other, which the model can stay out of.
    # recent_replies are named outright: the prompt's general "don't repeat
    # yourself" didn't stop it reusing a jab from one message earlier.
    def target_note(message, note, recent_replies = [])
      addressee =
        if note
          note
        elsif AiReplyGate.new(message).decision == :always
          "Воно адресоване тобі, тож відповідай."
        else
          "Воно не адресоване тобі напряму. Якшо там є \"ти\", це скоріше про того, з ким людина говорить. " \
            "Якшо це явно розмова між іншими людьми (хтось звертається до когось або продовжує з ним тему), " \
            "напиши рівно #{SKIP}. Якшо це для всього чату, відповідай."
        end

      repeats =
        if recent_replies.any?
          "Твої останні відповіді: #{recent_replies.map { |reply| "\"#{reply.truncate(200)}\"" }.join(', ')}. " \
            "Не повторюй з них слів, образів і підколів. "
        end

      "Ти відповідаєш на повідомлення від #{message.user&.name || 'когось'}: " \
        "\"#{message.content.to_s.truncate(200)}\". #{addressee} #{repeats}" \
        "Відповідь: одне коротке речення, до 15 слів."
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
