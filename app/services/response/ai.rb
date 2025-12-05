module Response
  class Ai < Response::Base
    def initialize(chat:)
      @chat = chat
    end

    def process
      ai_response = ::Ai.reply_in(@chat)
      success ai_response

    rescue OpenAI::Errors::RateLimitError
      nil
    end
  end
end