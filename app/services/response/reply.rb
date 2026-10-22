module Response
  # Replying to someone's message with a signed number gives ("+200") or
  # takes ("-100") that many жмихкоїни; a bare "100" is just a message.
  # Each member can give or take DAILY_BUDGET in total per chat per day:
  # +300 and -200 use it all up.
  class Reply
    include Responder

    DAILY_BUDGET = 500
    SIGNED_NUMBER = /\A[+-]\d+\z/

    def initialize(user:, text:, chat:, reply_to_message:)
      @user = user
      @text = text
      @chat = chat
      @reply_to_message = reply_to_message
    end

    def call
      return unless @reply_to_message

      signed = @text.strip[SIGNED_NUMBER]
      return unless signed

      # Base 10, so "+08" isn't read as a broken octal number.
      amount = Integer(signed, 10)
      return if amount.zero?

      # A replied-to channel post has no author ("from"), so no one to reward.
      receiver_id = @reply_to_message.dig(:from, :id)
      return unless receiver_id

      receiver = User.find_by(telegram_id: receiver_id)
      return if !receiver || @user == receiver

      reply(give(receiver, amount))
    end

    private

    # Locks the giver's row so two numbers sent at once can't both fit into
    # what's left of the budget.
    def give(receiver, amount)
      @user.with_lock do
        left = DAILY_BUDGET - spent_today
        next over_budget(left) if amount.abs > left

        point = receiver.points.create!(amount: amount, giver: @user, reason: @reply_to_message[:text], chat: @chat)
        point_answer(point, receiver)
      end
    end

    # Time.current is in the app time zone (Kyiv), so the day starts at
    # Kyiv midnight.
    def spent_today
      @user.given_points.where(chat: @chat, created_at: Time.current.all_day).sum(Arel.sql("ABS(amount)"))
    end

    def over_budget(left)
      return "Пʼятихатку жмихкоїнів на сьогодні вже вʼєбано, приходь завтра" if left.zero?

      "Сьогодні можна вʼєбать ще лише #{Zhmykhcoins.count(left)}, ліміт — пʼятихатка на день"
    end

    def point_answer(point, receiver)
      response = "#{receiver.name} отримує #{Zhmykhcoins.count(point.amount, signed: true)}"
      response += " по причині: \n\"#{point.reason}\"" if point.reason.present?
      response
    end
  end
end
