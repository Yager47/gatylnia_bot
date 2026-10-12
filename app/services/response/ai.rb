module Response
  class Ai
    include Responder

    def initialize(chat:, frames_for: nil, frame_paths: [])
      @chat = chat
      @frames_for = frames_for
      @frame_paths = frame_paths
    end

    def call
      reply(::Ai.reply_in(@chat, frames_for: @frames_for, frame_paths: @frame_paths))
    rescue OpenAI::Errors::RateLimitError
      nil
    end
  end
end
