module Zhmykhcoins
  # Monday's summary of the past Kyiv week in a chat with жмихкоїни:
  #   💰 Жмихкоїни за минулий тиждень:
  #
  #   👑 Жмихкоїн тижня: Петро, +340
  #
  #   Петро: +340 (разом 1200)
  #   Ольга: -50 (разом 300)
  #
  #   🎁 Найщедріший: Іван, роздав 450
  # Members whose balance didn't move are left out. Four queries however many
  # members and points there are.
  class WeeklySummary
    def initialize(chat, now: Time.current)
      @chat = chat
      @now = now
    end

    # Sends at most once per Monday. The chat row lock makes a parallel or
    # repeated run wait and then see the date; if sending fails, the date and
    # the assistant message roll back so a retry starts clean.
    def deliver
      today = @now.to_date

      @chat.with_lock do
        next if @chat.points_summary_sent_on == today

        if (body = text)
          reply = @chat.messages.create!(role: :assistant, content: body)
          ChatMessenger.new(chat: @chat).deliver(reply)
        end
        @chat.update!(points_summary_sent_on: today)
      end
    end

    # nil when nobody's balance moved.
    def text
      changes = week_points.group(:user_id).sum(:amount).reject { |_user_id, amount| amount.zero? }
      return if changes.empty?

      generous = week_points.where("amount > 0").where.not(giver_id: nil).group(:giver_id).sum(:amount).max_by { |_id, amount| amount }
      users = User.where(id: changes.keys + [ generous&.first ].compact).index_by(&:id)
      totals = @chat.points.where(user_id: changes.keys).group(:user_id).sum(:amount)
      ranked = changes.sort_by { |user_id, amount| [ -amount, users[user_id].name ] }

      [
        "💰 Жмихкоїни за минулий тиждень:",
        king_line(ranked, users),
        ranked.map { |user_id, amount| "#{users[user_id].name}: #{format('%+d', amount)} (разом #{totals.fetch(user_id)})" }.join("\n"),
        ("🎁 Найщедріший: #{users[generous.first].name}, роздав #{generous.last}" if generous)
      ].compact.join("\n\n")
    end

    private

    def week_points
      @chat.points.where(created_at: (@now - 1.week).all_week)
    end

    # Only for someone who came out ahead.
    def king_line(ranked, users)
      user_id, amount = ranked.first
      "👑 Жмихкоїн тижня: #{users[user_id].name}, #{Zhmykhcoins.count(amount, signed: true)}" if amount.positive?
    end
  end
end
