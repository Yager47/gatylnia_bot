module Response
  class RpsGame
    include Responder

    ROCK = "камінь".freeze
    PAPER = "папір".freeze
    SCISSORS = "ножиці".freeze
    WEAPONS = [ ROCK, PAPER, SCISSORS ].freeze
    # Weapon => the weapon it beats.
    BEATS = { ROCK => SCISSORS, PAPER => ROCK, SCISSORS => PAPER }.freeze
    STAKE = 10

    # random: anything with #rand, so specs can fix the bot's move.
    def initialize(user:, user_weapon:, chat:, random: Random)
      @user = user
      @user_weapon = user_weapon
      @chat = chat
      @random = random
    end

    def call
      return unless WEAPONS.include?(@user_weapon)

      reply(fight)
    end

    private

    def fight
      bot_weapon = WEAPONS.sample(random: @random)
      return pick(answers("rps_draw")) if @user_weapon == bot_weapon

      won = BEATS[@user_weapon] == bot_weapon
      sign, answers_name = won ? [ ">", "rps_win" ] : [ "<", "rps_lose" ]
      amount = won ? STAKE : -STAKE
      @user.points.create!(chat: @chat, amount: amount, reason: "RPS: #{@user_weapon} #{sign} #{bot_weapon}")

      "#{pick(answers(answers_name))} #{@user_weapon.capitalize} #{sign} #{bot_weapon.capitalize}. #{Zhmykhcoins.count(amount, signed: true)}"
    end
  end
end
