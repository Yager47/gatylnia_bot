module Response
  class Ai < Response::Base
    def initialize(chat:, frames_for: nil, frame_paths: [])
      @chat = chat
      @frames_for = frames_for
      @frame_paths = frame_paths
    end

    def process
      ai_response = ::Ai.reply_in(@chat, frames_for: @frames_for, frame_paths: @frame_paths)
      success ai_response

    rescue OpenAI::Errors::RateLimitError
      nil
    end
  end
end
