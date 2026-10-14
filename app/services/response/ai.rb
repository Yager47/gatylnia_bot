module Response
  class Ai
    include Responder

    # trigger: the message being answered. If someone writes again before the
    # reply is sent, the reply is dropped: the newer message gets its own turn
    # with the full context, instead of the bot answering both. A message
    # addressed to the bot (AiReplyGate's :always) is always answered.
    # frames_for: a video note, answered with its frames even if others wrote
    # since. The model may still decide a message isn't for it (Ai::SKIP).
    def initialize(chat:, trigger: nil, frames_for: nil, frame_paths: [])
      @chat = chat
      @trigger = trigger
      @frames_for = frames_for
      @frame_paths = frame_paths
    end

    def call
      return STOP if superseded?

      text = ::Ai.reply_in(@chat, target: @trigger || @frames_for, frame_paths: @frame_paths)
      # Checked again: the model takes seconds, the likeliest time for a new message.
      return STOP if superseded? || ::Ai.skip?(text)

      reply(text)
    rescue OpenAI::Errors::RateLimitError
      nil
    end

    private

    def superseded?
      return false if @trigger.nil? || AiReplyGate.new(@trigger).decision == :always

      @chat.messages.user.exists?([ "telegram_message_id > ?", @trigger.telegram_message_id ])
    end
  end
end
