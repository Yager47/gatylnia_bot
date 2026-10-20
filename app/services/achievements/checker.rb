module Achievements
  # Brings a chat's achievements for the current periods in line with what
  # its members qualify for now, and announces the difference in one
  # message: new ones are awarded, ones that grew go up a level, ones that
  # no longer hold are taken back, and a taken-back one that holds again is
  # restored. A second run with nothing new changes nothing. Closed periods
  # are never checked, so they stay as announced.
  class Checker
    # rules: the instant ones by default; Closer passes the period-end ones.
    # period_at: a time in the periods to check (now, or Closer's last
    # second of the period that just ended). header: a first line.
    def initialize(chat, rules: RULES.reject(&:period_end?), now: Time.current, period_at: now, header: nil)
      @chat = chat
      @rules = rules
      @now = now
      @period_at = period_at
      @header = header
    end

    # The chat row lock makes a parallel run wait and then see this one's
    # rows. If sending fails, the changes and the assistant message roll
    # back, so a retry announces them again.
    def call
      @chat.with_lock do
        next unless @chat.camerton_enabled?

        changes = @rules.flat_map { |rule| sync(rule) }
        next if changes.empty?

        reply = @chat.messages.create!(role: :assistant, content: text(changes))
        ChatMessenger.new(chat: @chat).deliver(reply, parse_mode: "HTML")
      end
    end

    private

    # Returns [[:awarded | :leveled | :revoked, rule, achievement], ...].
    def sync(rule)
      period = Period.current(rule.period_kind, now: @period_at)
      levels = rule.levels(@chat, period)
      rows = @chat.achievements.where(code: rule.code, period: period.key).index_by(&:user_id)

      kept = levels.filter_map { |user_id, level| keep(rule, period, rows[user_id], user_id, level) }
      revoked = rows.values.reject { |row| row.revoked? || levels.key?(row.user_id) }
      revoked.each { |row| row.update!(revoked_at: @now) }

      kept.map { |change, row| [ change, rule, row ] } + revoked.map { |row| [ :revoked, rule, row ] }
    end

    # [change, row] for a new, restored or higher-level achievement, or nil
    # when nothing worth announcing changed. A level that went down (a
    # review removed) is stored silently.
    def keep(rule, period, row, user_id, level)
      if row.nil?
        [ :awarded, @chat.achievements.create!(user_id: user_id, code: rule.code, period: period.key, level: level, awarded_at: @now) ]
      elsif row.revoked?
        row.update!(revoked_at: nil, awarded_at: @now, level: level)
        [ :awarded, row ]
      elsif level != row.level
        raised = level.to_i > row.level.to_i
        row.update!(level: level)
        [ :leveled, row ] if raised
      end
    end

    def text(changes)
      users = User.where(id: changes.map { |_change, _rule, row| row.user_id }).index_by(&:id)

      lines = changes.map do |change, rule, row|
        rule.line(change, Camerton::Formatting.mention(users.fetch(row.user_id)), row.level)
      end
      [ @header, *lines ].compact.join("\n")
    end
  end
end
