module Activities
  # The жмихкоїни a freshly recorded activity earns, as a Point linked to it.
  # Push-ups pay for the first PUSH_UP_SETS sets of the day; coffee by the
  # cup's number that day, and from the fifth cup it costs.
  class Reward
    PUSH_UPS = 100
    PUSH_UP_SETS = 3
    # Cup number that day => жмихкоїни.
    COFFEE = { 1..2 => 25, 3..4 => 10, 5.. => -10 }.freeze

    def initialize(activity)
      @activity = activity
    end

    # The Point, or nil when the activity earns nothing. Locks the user's row
    # so two activities recorded at once are numbered one after the other.
    def grant
      @activity.user.with_lock do
        number = number_today
        amount = @activity.coffee? ? COFFEE.find { |cups, _| cups.cover?(number) }.last : push_ups_amount(number)
        next unless amount

        @activity.create_reward!(user: @activity.user, chat: @activity.chat, amount: amount, reason: reason(number))
      end
    end

    private

    # This activity's number among the user's activities of its kind that
    # Kyiv day, counting earlier ones only: a late retry doesn't renumber.
    def number_today
      Activity.where(user_id: @activity.user_id, chat_id: @activity.chat_id, kind: @activity.kind)
              .where(occurred_at: @activity.occurred_at.beginning_of_day..@activity.occurred_at)
              .sum(:amount)
    end

    def push_ups_amount(number)
      PUSH_UPS if number <= PUSH_UP_SETS
    end

    def reason(number)
      @activity.coffee? ? "Кава №#{number}" : "Відтискання, підхід №#{number}"
    end
  end
end
