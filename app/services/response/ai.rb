module Response
  class Ai < Response::Base
    def initialize(chat:, vision_frame_path: nil)
      @chat = chat
      @vision_frame_path = vision_frame_path
    end

    def process
      ai_response = ::Ai.reply_in(@chat, vision_frame_path: @vision_frame_path)
      success ai_response

    rescue OpenAI::Errors::RateLimitError
      nil
    end
  end
end
