module Response
  # "видали каву": removes the author's latest coffee in this chat, whether it
  # came from text or a video note. Push-ups can't be undone, on purpose.
  class UndoCoffee < Response::Base
    PHRASE = "видали каву".freeze

    def initialize(user:, text:, chat:)
      super(user: user, text: text)

      @chat = chat
    end

    def call
      return unless @text.strip == PHRASE

      last_coffee = @chat.activities.coffee.where(user: @user).order(:occurred_at, :id).last
      return reply("Ти ще тут не пив каву") unless last_coffee

      last_coffee.destroy!
      reply("Видалив твою останню каву. Сьогодні: #{today_total}")
    end

    private

    def today_total
      @chat.activities.coffee.where(user: @user, occurred_at: Time.current.all_day).sum(:amount)
    end
  end
end
