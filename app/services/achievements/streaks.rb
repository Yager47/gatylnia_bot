module Achievements
  # Серія: follows each member's runs of consecutive Kyiv days with a scored
  # review (dated by its first message), one achievement per run
  # ("streak-2026-10-19", level = days). Announces the start (day 3), the
  # milestones, the end (a day went by without a review), and a take-back
  # when removed reviews leave a run under 3 days. Runs that ended before
  # it saw them are left alone. Same lock and rollback as the Checker.
  class Streaks
    def initialize(chat, rule: RULES.find { |candidate| candidate.decided_by == :streaks }, now: Time.current)
      @chat = chat
      @rule = rule
      @now = now
    end

    def call
      @chat.with_lock do
        next unless @chat.camerton_enabled?

        changes = sync
        next if changes.empty?

        reply = @chat.messages.create!(role: :assistant, content: text(changes))
        ChatMessenger.new(chat: @chat).deliver(reply, parse_mode: "HTML")
      end
    end

    private

    # Returns [[:awarded | :milestone | :finished | :revoked, achievement], ...].
    def sync
      yesterday = @now.to_date - 1
      rows = @chat.achievements.where(code: @rule.code).index_by { |row| [ row.user_id, row.period ] }
      live_keys = Set.new

      changes = runs.filter_map do |user_id, first_day, last_day, days|
        key = [ user_id, "streak-#{first_day.iso8601}" ]
        live_keys << key
        follow(rows[key], key, days, alive: last_day >= yesterday)
      end

      gone = rows.except(*live_keys).values.reject { |row| row.revoked? || row.finished_at }
      gone.each { |row| row.update!(revoked_at: @now) }
      changes + gone.map { |row| [ :revoked, row ] }
    end

    def follow(row, (user_id, period), days, alive:)
      if row.nil?
        [ :awarded, @chat.achievements.create!(user_id: user_id, code: @rule.code, period: period, level: days, awarded_at: @now) ] if alive
      elsif row.revoked?
        [ :awarded, row.tap { row.update!(revoked_at: nil, level: days, awarded_at: @now) } ] if alive
      elsif row.finished_at.nil?
        alive ? grow(row, days) : [ :finished, row.tap { row.update!(level: days, finished_at: @now) } ]
      end
    end

    # A milestone passed on the way is announced; a shorter run (a review
    # removed) is stored silently.
    def grow(row, days)
      return if days == row.level

      passed = ((row.level + 1)..days).any? { |day| @rule.milestone?(day) }
      row.update!(level: days)
      [ :milestone, row ] if passed
    end

    # [[user_id, first day, last day, days], ...] of runs of at least
    # Streak::MIN_DAYS: each day minus its rank among the member's days is
    # the same within a run (gaps and islands). Three queries in one.
    def runs
      local_day = Review.sanitize_sql_array([
        "DISTINCT reviews.user_id, ((firsts.first_at AT TIME ZONE 'UTC') AT TIME ZONE ?)::date AS day",
        Time.zone.tzinfo.name
      ])
      days = Reviews.dated(@chat).select(local_day)
      islands = Review.from(days, :days)
        .select("days.user_id, days.day, days.day - (ROW_NUMBER() OVER (PARTITION BY days.user_id ORDER BY days.day))::integer AS island")

      Review.from(islands, :islands).group("islands.user_id", "islands.island")
        .having("COUNT(*) >= ?", Rules::Streak::MIN_DAYS)
        .pluck(Arel.sql("islands.user_id"), Arel.sql("MIN(islands.day)"), Arel.sql("MAX(islands.day)"), Arel.sql("COUNT(*)"))
    end

    def text(changes)
      users = User.where(id: changes.map { |_change, row| row.user_id }).index_by(&:id)

      changes.map do |change, row|
        mention = Camerton::Formatting.mention(users.fetch(row.user_id))
        days = @rule.days(row.level)
        case change
        when :awarded then "🏆 #{mention} отримує ачівку «#{@rule.title}»: #{days} поспіль з оцінками 🔥"
        when :milestone then "🔥 Серія #{mention}: #{days} поспіль"
        when :finished then "💔 Серія #{mention} закінчилась: #{days} поспіль"
        when :revoked then "↩️ #{mention} втрачає ачівку «#{@rule.title}»: оцінок поспіль уже менше #{Rules::Streak::MIN_DAYS}"
        end
      end.join("\n")
    end
  end
end
