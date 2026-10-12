module Camerton
  # Camerton's part of a message in a chat with it on, run before the mode
  # handler: a music link becomes a share, and a reply to a share (or to the
  # bot's announcement of it) becomes feedback. A reply that shares a new link
  # counts as a share only.
  class Handler
    def initialize(message:, chat:)
      @message = message
      @chat = chat
    end

    def call
      ShareRecorder.new(message: @message, chat: @chat).call ||
        ReviewRecorder.new(message: @message, chat: @chat).call
    end
  end
end
