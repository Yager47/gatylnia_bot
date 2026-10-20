module Achievements
  # Decides the achievements of the week or month that just ended
  # (config/recurring.yml: Mondays and the 1st, 09:00 Kyiv), in one message
  # under a header. Checks the period before `now`, so a retry or a second
  # run changes nothing; nothing looks at that period again afterwards.
  class Closer
    HEADERS = { week: "🏁 Підсумки тижня:", month: "🏁 Підсумки місяця:" }.freeze

    def initialize(chat, kind, now: Time.current)
      @chat = chat
      @kind = kind
      @now = now
    end

    def call
      rules = RULES.select { |rule| rule.period_end? && rule.period_kind == @kind }
      last_second = Period.current(@kind, now: @now).range.begin - 1.second

      Checker.new(@chat, rules: rules, now: @now, period_at: last_second, header: HEADERS.fetch(@kind)).call
    end
  end
end
