module Response
  class Gato
    include Responder

    REMOVE_PHRASE = "видали гатіння".freeze
    # A chat this new still gets told how to log a gato properly.
    ONBOARDING_PERIOD = 1.week
    # How often a counted gato gets an AI comment instead of a canned line
    # (rolled by the caller).
    AI_CHANCE = 0.9
    COUNTED = "Гатіння зараховано.".freeze
    # Doesn't quote COUNTED: quoting it made the model write it anyway.
    AI_NOTE = "Бот уже підтвердив зарахування цього гатіння, і твій текст піде одразу після підтвердження. " \
      "Напиши лише один короткий підкол про це гатіння, саме підтвердження не пиши.".freeze
    # COUNTED as the model writes it anyway: any case or punctuation, anywhere.
    COUNTED_ECHO = /гатіння\s+зараховано[[:punct:]]*\s*/i

    # comment_with_ai: answer a counted gato with COUNTED plus an AI comment
    # on message (the recorded Message) instead of a canned line.
    def initialize(user:, text:, original_text:, chat:, message: nil, comment_with_ai: false)
      @user = user
      @text = text
      @original_text = original_text
      @chat = chat
      @message = message
      @comment_with_ai = comment_with_ai
    end

    def call
      if phrases("gato").include?(@text)
        add_entry
      elsif @text == REMOVE_PHRASE
        remove_entry
      elsif @text.include?("гат") && @chat.created_at > ONBOARDING_PERIOD.ago
        reply(explanation)
      end
    end

    private

    def add_entry
      @user.entries.create!(chat: @chat, message: @original_text)
      reply(ai_comment || gato_response)
    end

    # nil (so the canned line is used) when not asked for, when the model
    # skips or when OpenAI fails: the gato is counted either way, no retry needed.
    def ai_comment
      return unless @comment_with_ai && @message

      text = ::Ai.reply_in(@chat, target: @message, note: AI_NOTE)
      text = text.to_s.gsub(COUNTED_ECHO, "").strip
      "#{COUNTED} #{text}" unless text.empty? || ::Ai.skip?(text)
    rescue OpenAI::Errors::Error => e
      Rails.logger.warn("[Response::Gato] AI comment failed: #{e.class}: #{e.message}")
      nil
    end

    def remove_entry
      reply(Removals::Remover.new(user: @user, chat: @chat).gato)
    end

    def gato_response
      pick(render_answers(
        "gato",
        text: @text,
        rhythm: TimeSignature.call,
        first_name: @chat.member_names.first_name(@user),
        last_name: @user.last_name,
        chat_title: @chat.title
      ))
    end

    def explanation
      "Якшо ти гатиш, напиши нормально, одним словом: гатю, погатив, сру, насрав, посрав, какаю і т.д.\n\n" \
        "Якшо ти хочеш, шоб я видалив твоє останнє гатіння, напиши: \"#{REMOVE_PHRASE}\""
    end
  end
end
