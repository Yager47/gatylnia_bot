module Response
  class RpsGame < Response::Base
    ROCK = "камінь"
    PAPER = "папір"
    SCISSORS = "ножиці"
    FEE = 10

    def initialize(user:, user_weapon:, chat:)
      @user = user
      @user_weapon = user_weapon
      @chat = chat
    end

    def process
      return unless weapons.include?(@user_weapon)

      response = fight
      success response
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
        [ROCK, SCISSORS],
        [PAPER, ROCK],
        [SCISSORS, PAPER]
      ].include? [@user_weapon, computer_weapon]
    end

    def weapons
      [ROCK, PAPER, SCISSORS]
    end

    def win_answer
      answers("rps_win").sample
    end

    def lose_answer
      answers("rps_lose").sample
    end

    def draw_answer
      answers("rps_draw").sample
    end
  end
end