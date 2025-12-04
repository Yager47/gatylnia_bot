module Response
  class Ai < Response::Base
    def initialize(text:)
      @text = text
    end

    def process
      ai_response = ::Ai.reply_to(@text)
      success ai_response

    rescue OpenAI::Errors::RateLimitError
      nil
    end
  end
end