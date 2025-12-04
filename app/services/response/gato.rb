module Response
  class Gato < Response::Base
    def initialize(user:, text:, original_text:, chat:)
      super(user: user, text: text)

      @original_text = original_text
      @chat = chat
    end

    def process
      if phrases("gato").include?(@text)
        add_entry
      elsif @text == "видали гатіння"
        remove_entry
      elsif @text.include?("гат") && @chat.created_at > Time.now - 1.week
        success explanation
      end
    end

    private

    def add_entry
      @user.entries.create!(chat: @chat, message: @original_text)
      success gato_response
    end

    def remove_entry
      last_entry = @user.entries.last

      if last_entry
        last_entry.destroy
        success "Твоє останнє гатіння видалено. \nТіряйся"
      else
        success "Ти ще тут не гатив, придурок"
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

      answers("gato", params).sample
    end

    def explanation
      "Якшо ти гатиш, напиши нормально, одним словом: гатю, погатив, сру, насрав, посрав, какаю і т.д.\n\n" \
        "Якшо ти хочеш, шоб я видалив твоє останнє гатіння, напиши: \"видали гатіння\""
    end
  end
end