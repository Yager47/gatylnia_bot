module Response
  class Gato
    include Responder

    REMOVE_PHRASE = "видали гатіння".freeze
    # A chat this new still gets told how to log a gato properly.
    ONBOARDING_PERIOD = 1.week

    def initialize(user:, text:, original_text:, chat:)
      @user = user
      @text = text
      @original_text = original_text
      @chat = chat
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
      reply(gato_response)
    end

    def remove_entry
      last_entry = @user.entries.where(chat: @chat).order(:created_at, :id).last

      if last_entry
        last_entry.destroy!
        reply("Твоє останнє гатіння видалено. \nТіряйся")
      else
        reply("Ти ще тут не гатив, придурок")
      end
    end

    def gato_response
      pick(render_answers(
        "gato",
        text: @text,
        rhythm: TimeSignature.call,
        first_name: @user.first_name,
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
