module Response
  # "видали каву": removes the author's latest coffee in this chat, whether it
  # came from text or a video note. Push-ups can't be undone, on purpose.
  # Other wordings, addressed to the bot, go through Response::Removal.
  class UndoCoffee
    include Responder

    PHRASE = "видали каву".freeze

    def initialize(user:, text:, chat:)
      @user = user
      @text = text
      @chat = chat
    end

    def call
      return unless @text.strip == PHRASE

      reply(Removals::Remover.new(user: @user, chat: @chat).coffee)
    end
  end
end
