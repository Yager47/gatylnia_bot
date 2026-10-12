module Response
  class Gato
    include Responder

    def initialize(user:, text:, original_text:, chat:)
      @user = user
      @text = text
      @original_text = original_text
      @chat = chat
    end

    def call
      if phrases("gato").include?(@text)
        add_entry
      elsif @text == "видали гатіння"
        remove_entry
      elsif @text.include?("гат") && @chat.created_at > Time.now - 1.week
        reply(explanation)
      end
    end

    private

    def add_entry
      @user.entries.create!(chat: @chat, message: @original_text)
      reply(gato_response)
    end

    def remove_entry
      last_entry = @user.entries.where(chat: @chat).last

      if last_entry
        last_entry.destroy
        reply("Твоє останнє гатіння видалено. \nТіряйся")
      else
        reply("Ти ще тут не гатив, придурок")
      end
    end

    def gato_response
      params = {
        text: @text,
        rhythm: TimeSignature.call,
        first_name: @user.first_name,
        last_name: @user.last_name,
        chat_title: @chat.title
      }

      pick(render_answers("gato", **params))
    end

    def explanation
      "Якшо ти гатиш, напиши нормально, одним словом: гатю, погатив, сру, насрав, посрав, какаю і т.д.\n\n" \
        "Якшо ти хочеш, шоб я видалив твоє останнє гатіння, напиши: \"видали гатіння\""
    end
  end
end
