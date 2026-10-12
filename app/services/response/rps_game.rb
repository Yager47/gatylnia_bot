module Response
  class RpsGame
    include Responder

    ROCK = "камінь"
    PAPER = "папір"
    SCISSORS = "ножиці"
    FEE = 10

    def initialize(user:, user_weapon:, chat:)
      @user = user
      @user_weapon = user_weapon
      @chat = chat
    end

    def call
      return unless weapons.include?(@user_weapon)

      reply(fight)
    end

    private

    def fight
      computer_weapon = weapons.sample

      if @user_weapon == computer_weapon
        draw_answer
      elsif user_won?(computer_weapon)
        @user.points.create!(chat: @chat, amount: FEE, reason: "RPS: #{@user_weapon} > #{computer_weapon}")
        "#{win_answer} #{@user_weapon.capitalize} > #{computer_weapon.capitalize}. +#{FEE}"
      else
        @user.points.create!(chat: @chat, amount: -FEE, reason: "RPS: #{@user_weapon} < #{computer_weapon}")
        "#{lose_answer} #{@user_weapon.capitalize} < #{computer_weapon.capitalize}. -#{FEE}"
      end
    end

    def user_won?(computer_weapon)
      [
        [ ROCK, SCISSORS ],
        [ PAPER, ROCK ],
        [ SCISSORS, PAPER ]
      ].include? [ @user_weapon, computer_weapon ]
    end

    def weapons
      [ ROCK, PAPER, SCISSORS ]
    end

    def win_answer
      pick(answers("rps_win"))
    end

    def lose_answer
      pick(answers("rps_lose"))
    end

    def draw_answer
      pick(answers("rps_draw"))
    end
  end
end
