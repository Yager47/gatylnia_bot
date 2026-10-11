module Activities
  # The short reply confirming freshly recorded activities, with the user's
  # totals for that day: "☕ Петро: 2 за сьогодні", "💪 Петро: 1 підхід за
  # сьогодні", "☕💪 Петро: 2 кави, 1 підхід відтискань за сьогодні".
  class Confirmation
    EMOJI = { coffee: "☕", push_ups: "💪" }.freeze

    def initialize(user:, chat:, day:)
      @user = user
      @chat = chat
      @day = day
    end

    # recorded: kind => amount just recorded, e.g. { coffee: 2 }.
    def text(recorded)
      totals = @chat.activities.where(user: @user, kind: recorded.keys, occurred_at: @day.all_day).group(:kind).sum(:amount)
      emoji = recorded.map { |kind, amount| EMOJI.fetch(kind) * amount }.join

      summary = if recorded.size == 1
        single_summary(recorded.keys.first, totals.fetch(recorded.keys.first.to_s))
      else
        recorded.keys.map { |kind| "#{totals.fetch(kind.to_s)} #{label(kind, totals.fetch(kind.to_s))}" }.join(", ")
      end

      "#{emoji} #{@user.name}: #{summary} за сьогодні"
    end

    private

    def single_summary(kind, total)
      kind == :push_ups ? "#{total} #{plural(total, 'підхід', 'підходи', 'підходів')}" : total.to_s
    end

    def label(kind, total)
      if kind == :coffee
        plural(total, "кава", "кави", "кав")
      else
        plural(total, "підхід відтискань", "підходи відтискань", "підходів відтискань")
      end
    end

    # Ukrainian plural: one for 1, 21, 31; few for 2-4, 22-24; many for
    # 5-20, 25-30 (11-14 are always many).
    def plural(count, one, few, many)
      if count % 10 == 1 && count % 100 != 11
        one
      elsif (2..4).cover?(count % 10) && !(12..14).cover?(count % 100)
        few
      else
        many
      end
    end
  end
end
