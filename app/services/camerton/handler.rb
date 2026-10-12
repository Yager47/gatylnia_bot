module Camerton
  # Camerton's part of a message in a chat with it on, run before the mode
  # handler: a music link becomes a share, and a reply to a share (or to the
  # bot's announcement of it) becomes feedback, typed or spoken. A reply that
  # shares a new link counts as a share only.
  class Handler
    def initialize(message:, chat:)
      @message = message
      @chat = chat
    end

    # Returns what the message was to Camerton: :share, :review or nil.
    def call
      return :share if ShareRecorder.new(message: @message, chat: @chat).call

      :review if ReviewRecorder.new(message: @message, chat: @chat).call
    end
  end
end
