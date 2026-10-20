module Achievements
  # Decides the achievements of the week or month that just ended
  # (config/recurring.yml: Mondays and the 1st, 09:00 Kyiv), or of the
  # releases that turned a week old (:release, daily), in one message under
  # a header. A retry or a second run changes nothing, and nothing looks at
  # those periods again afterwards.
  class Closer
    HEADERS = { week: "🏁 Підсумки тижня:", month: "🏁 Підсумки місяця:", release: "🏁 Релізи тижневої давності:" }.freeze

    def initialize(chat, kind, now: Time.current)
      @chat = chat
      @kind = kind
      @now = now
    end

    def call
      rules = RULES.select { |rule| rule.period_end? && rule.period_kind == @kind }
      period_at = @kind == :release ? @now : Period.current(@kind, now: @now).range.begin - 1.second

      Checker.new(@chat, rules: rules, now: @now, period_at: period_at, header: HEADERS.fetch(@kind)).call
    end
  end
end
