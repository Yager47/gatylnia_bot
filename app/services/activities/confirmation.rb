module Activities
  # The short reply confirming freshly recorded activities, with the user's
  # totals for that day: "☕ Петро: 2 за сьогодні", "💪 Петро: 1 підхід за
  # сьогодні", "☕💪 Петро: 2 кави, 1 підхід відтискань за сьогодні", plus
  # the жмихкоїни they earned: "☕ Петро: 1 за сьогодні, +25 жмихкоїнів".
  class Confirmation
    EMOJI = { coffee: "☕", push_ups: "💪" }.freeze

    def initialize(user:, chat:, day:)
      @user = user
      @chat = chat
      @day = day
    end

    # recorded: kind => amount just recorded, e.g. { coffee: 2 }.
    # reward: the жмихкоїни those earned in total; nothing is said for 0.
    def text(recorded, reward: 0)
      totals = @chat.activities.where(user: @user, kind: recorded.keys, occurred_at: @day.all_day).group(:kind).sum(:amount)
      emoji = recorded.map { |kind, amount| EMOJI.fetch(kind) * amount }.join

      summary = if recorded.size == 1
        single_summary(recorded.keys.first, totals.fetch(recorded.keys.first.to_s))
      else
        recorded.keys.map { |kind| "#{totals.fetch(kind.to_s)} #{label(kind, totals.fetch(kind.to_s))}" }.join(", ")
      end

      text = "#{emoji} #{@user.name}: #{summary} за сьогодні"
      reward.zero? ? text : "#{text}, #{Zhmykhcoins.count(reward, signed: true)}"
    end

    private

    def single_summary(kind, total)
      kind == :push_ups ? "#{total} #{Plural.word(total, 'підхід', 'підходи', 'підходів')}" : total.to_s
    end

    def label(kind, total)
      if kind == :coffee
        Plural.word(total, "кава", "кави", "кав")
      else
        Plural.word(total, "підхід відтискань", "підходи відтискань", "підходів відтискань")
      end
    end
  end
end
