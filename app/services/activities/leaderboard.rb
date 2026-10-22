module Activities
  # Totals per user for one kind of activity in a chat, highest first.
  # Three queries regardless of chat size: one grouped sum, one for the
  # users, one for their pseudonyms.
  class Leaderboard
    Row = Data.define(:user, :total)

    def initialize(chat:, kind:, range:)
      @chat = chat
      @kind = kind
      @range = range
    end

    def rows
      totals = @chat.activities.where(kind: @kind, occurred_at: @range).group(:user_id).sum(:amount)
      users = User.where(id: totals.keys).index_by(&:id)

      totals.map { |user_id, total| Row.new(user: users.fetch(user_id), total: total) }
            .sort_by { |row| [ -row.total, @chat.member_names.name(row.user) ] }
    end
  end
end
