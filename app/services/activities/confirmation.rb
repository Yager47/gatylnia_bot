module Activities
  # The short reply confirming freshly recorded activities, with the user's
  # totals for that day: "☕ Петро: 2 за сьогодні",
  # "☕💪 Петро: 2 кави, 1 підхід відтискань за сьогодні".
  class Confirmation
    EMOJI = { coffee: "☕", push_ups: "💪" }.freeze
    LABELS = { coffee: "кава", push_ups: "підхід відтискань" }.freeze

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
        totals.fetch(recorded.keys.first.to_s).to_s
      else
        recorded.keys.map { |kind| "#{totals.fetch(kind.to_s)} #{label(kind, totals.fetch(kind.to_s))}" }.join(", ")
      end

      "#{emoji} #{@user.name}: #{summary} за сьогодні"
    end

    private

    def label(kind, total)
      kind == :coffee ? coffee_label(total) : LABELS.fetch(kind)
    end

    # Ukrainian plural: 1, 21, 31 кава; 2-4, 22-24 кави; 5-20, 25-30 кав.
    def coffee_label(count)
      if count % 10 == 1 && count % 100 != 11
        "кава"
      elsif (2..4).cover?(count % 10) && !(12..14).cover?(count % 100)
        "кави"
      else
        "кав"
      end
    end
  end
end
