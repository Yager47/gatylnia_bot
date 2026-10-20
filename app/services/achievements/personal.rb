module Achievements
  # "@bot мої ачівки" / "@bot мої досягнення": what a member has in the
  # current periods, how far they are towards the rest, and everything
  # they've earned. Secret achievements appear only once earned. One query
  # per rule, plus two.
  #   🏆 Ачівки: Оля
  #
  #   Цього місяця:
  #   ✅ Пісенний Напівмарафонець
  #   ⏳ Пісенний Марафонець — 25/42
  #
  #   Цього тижня:
  #   ✅ Перевзувач (2)
  #
  #   Усього: Пісенний Напівмарафонець ×3
  class Personal
    PERIOD_LABELS = { week: "Цього тижня:", month: "Цього місяця:" }.freeze

    def initialize(chat:, user:, rules: RULES, now: Time.current)
      @chat = chat
      @user = user
      @rules = rules
      @now = now
    end

    def text
      [ "🏆 Ачівки: #{@user.name}", *current_sections, totals ].join("\n\n")
    end

    private

    def mine
      @chat.achievements.active.where(user: @user)
    end

    # Per-release achievements have no current period; they show in totals.
    def current_sections
      rules = @rules.select { |rule| PERIOD_LABELS.key?(rule.period_kind) }
      periods = rules.map(&:period_kind).uniq.index_with { |kind| Period.current(kind, now: @now) }
      held = mine.where(period: periods.values.map(&:key)).pluck(:code, :period, :level)
        .to_h { |code, key, level| [ [ code, key ], level ] }

      rules.group_by(&:period_kind).filter_map do |kind, kind_rules|
        period = periods.fetch(kind)
        lines = kind_rules.filter_map { |rule| current_line(rule, period, held) }
        [ PERIOD_LABELS.fetch(kind), *lines ].join("\n") if lines.any?
      end
    end

    # held: { [code, period key] => level (nil for plain ones) }
    def current_line(rule, period, held)
      key = [ rule.code, period.key ]
      return "✅ #{rule.title}#{" (#{held[key]})" if held[key]}" if held.key?(key)
      return if rule.secret? || rule.goal.nil?

      "⏳ #{rule.title} — #{rule.counts(@chat, period).fetch(@user.id, 0)}/#{rule.goal}"
    end

    def totals
      counts = mine.group(:code).count
      earned = @rules.select { |rule| counts.key?(rule.code) }
      return "Ще жодної ачівки — все попереду." if earned.empty?

      "Усього: " + earned.map { |rule| "#{rule.title} ×#{counts.fetch(rule.code)}" }.join(", ")
    end
  end
end
