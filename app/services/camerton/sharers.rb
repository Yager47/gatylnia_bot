module Camerton
  # "@bot камертони": who shares releases and how the chat scores them. A
  # release shared by two members counts for both; every score counts, the
  # sharer's own included.
  #
  # A release every member of the chat scored as bad, the sharer included,
  # is left out: everyone agrees it's a flop, so it was likely shared as one.
  # Four queries however many shares there are.
  class Sharers
    def initialize(chat:)
      @chat = chat
    end

    def text
      rows = sharer_rows
      return "🎛 Камертони:\n\nЩе ніхто нічого не скинув." if rows.empty?

      users = User.where(id: rows.map(&:first)).index_by(&:id)
      rows = rows.map { |user_id, releases, average, scores| [ users.fetch(user_id), releases, average, scores ] }
        .sort_by { |user, releases, average, _scores| [ average ? -average : Float::INFINITY, -releases, user.name ] }

      [ "🎛 Камертони (чиї релізи заходять найкраще):", "", *rows.map { |row| line(*row) }, *flops_note ].join("\n")
    end

    private

    # Releases every member of the chat scored as bad. Each member has at
    # most one review per release, so "every member" is a count.
    def unanimous_flops
      @unanimous_flops ||= begin
        members = ChatUser.where(chat: @chat).select(:user_id)
        Review.where(chat: @chat, score: Review::LABELS[:bad], user_id: members)
          .group(:release_id).having("COUNT(*) = (?)", ChatUser.where(chat: @chat).select("COUNT(*)"))
          .select(:release_id)
      end
    end

    def flops_note
      count = @chat.release_shares.where(release_id: unanimous_flops).distinct.count(:release_id)
      return [] if count.zero?

      [ "", "Без #{Formatting.count(count, 'релізу', 'релізів', 'релізів')}, які не зайшли нікому, навіть тому, хто скинув." ]
    end

    # [[user_id, distinct releases shared, average score or nil, scores], ...]
    def sharer_rows
      pairs = @chat.release_shares.where.not(release_id: unanimous_flops).select(:user_id, :release_id).distinct
      reviews_join = ActiveRecord::Base.sanitize_sql_array([
        "LEFT JOIN reviews ON reviews.release_id = pairs.release_id AND reviews.chat_id = ? AND reviews.score IS NOT NULL",
        @chat.id
      ])

      ReleaseShare.unscoped.from(pairs, :pairs).joins(reviews_join).group("pairs.user_id")
        .pluck(Arel.sql("pairs.user_id"), Arel.sql("COUNT(DISTINCT pairs.release_id)"),
          Arel.sql("AVG(reviews.score)"), Arel.sql("COUNT(reviews.id)"))
    end

    def line(user, releases, average, scores)
      shared = Formatting.count(releases, "реліз", "релізи", "релізів")
      return "#{user.name}: #{shared}, оцінок ще нема" unless average

      "#{user.name}: #{shared}, середня #{Formatting.score(average)} (#{Formatting.count(scores, 'оцінка', 'оцінки', 'оцінок')})"
    end
  end
end
