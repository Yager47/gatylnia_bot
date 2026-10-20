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

    def current_sections
      periods = @rules.map(&:period_kind).uniq.index_with { |kind| Period.current(kind, now: @now) }
      held = mine.where(period: periods.values.map(&:key)).pluck(:code, :period).to_set

      @rules.group_by(&:period_kind).filter_map do |kind, rules|
        period = periods.fetch(kind)
        lines = rules.filter_map { |rule| current_line(rule, period, held.include?([ rule.code, period.key ])) }
        [ PERIOD_LABELS.fetch(kind), *lines ].join("\n") if lines.any?
      end
    end

    def current_line(rule, period, held)
      return "✅ #{rule.title}" if held
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
