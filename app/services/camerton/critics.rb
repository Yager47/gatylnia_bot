module Camerton
  # "@bot критики": how many releases each member scored and how generous
  # they are. Two queries however many members and reviews there are.
  class Critics
    # Fewer scores than this say little about how strict someone is.
    MIN_FOR_EXTREMES = 3

    def initialize(chat:)
      @chat = chat
    end

    def text
      rows = Review.where(chat: @chat).where.not(score: nil)
        .group(:user_id).pluck(:user_id, Arel.sql("COUNT(*)"), Arel.sql("AVG(score)"))
      return "🧐 Критики:\n\nЩе ніхто нічого не оцінив." if rows.empty?

      users = User.where(id: rows.map(&:first)).index_by(&:id)
      rows = rows.map { |user_id, count, average| [ users.fetch(user_id), count, average ] }
        .sort_by { |user, count, average| [ average, -count, user.name ] }

      [ "🧐 Критики (від найсуворіших):", "", *lines(rows), *extremes(rows) ].join("\n")
    end

    private

    def lines(rows)
      rows.map do |user, count, average|
        "#{user.name}: #{Formatting.count(count, 'оцінка', 'оцінки', 'оцінок')}, середня #{Formatting.score(average)}"
      end
    end

    def extremes(rows)
      ranked = rows.select { |_user, count, _average| count >= MIN_FOR_EXTREMES }
      return [] if ranked.size < 2

      harshest = ranked.first
      kindest = ranked.last
      [
        "",
        "Найсуворіші оцінки: #{harshest[0].name} (#{Formatting.score(harshest[2])})",
        "Найщедріші оцінки: #{kindest[0].name} (#{Formatting.score(kindest[2])})"
      ]
    end
  end
end
