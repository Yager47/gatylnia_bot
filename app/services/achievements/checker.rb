module Achievements
  # Brings a chat's achievements for the current periods in line with what
  # its members qualify for now, and announces the difference in one
  # message: new ones are awarded, ones that no longer hold are taken back,
  # and a taken-back one that holds again is restored. A second run with
  # nothing new changes nothing. Closed periods are never checked, so they
  # stay as announced.
  class Checker
    def initialize(chat, rules: RULES, now: Time.current)
      @chat = chat
      @rules = rules
      @now = now
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

    # Returns [[:awarded | :revoked, rule, achievement], ...].
    def sync(rule)
      period = Period.current(rule.period_kind, now: @now)
      winner_ids = rule.winner_ids(@chat, period).to_set
      rows = @chat.achievements.where(code: rule.code, period: period.key).index_by(&:user_id)

      awarded = winner_ids.filter_map { |user_id| award(rule, period, rows[user_id], user_id) }
      revoked = rows.values.reject { |row| row.revoked? || winner_ids.include?(row.user_id) }
      revoked.each { |row| row.update!(revoked_at: @now) }

      awarded.map { |row| [ :awarded, rule, row ] } + revoked.map { |row| [ :revoked, rule, row ] }
    end

    # The new or restored row, or nil when the member already has it.
    def award(rule, period, row, user_id)
      if row.nil?
        @chat.achievements.create!(user_id: user_id, code: rule.code, period: period.key, awarded_at: @now)
      elsif row.revoked?
        row.tap { row.update!(revoked_at: nil, awarded_at: @now) }
      end
    end

    def text(changes)
      users = User.where(id: changes.map { |_change, _rule, row| row.user_id }).index_by(&:id)

      changes.map do |change, rule, row|
        mention = Camerton::Formatting.mention(users.fetch(row.user_id))
        if change == :awarded
          "🏆 #{mention} отримує ачівку «#{rule.title}»: #{rule.description}"
        else
          "↩️ #{mention} втрачає ачівку «#{rule.title}»: вже не #{rule.description}"
        end
      end.join("\n")
    end
  end
end
