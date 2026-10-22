module Camerton
  # The chat's best or worst releases by average score, optionally only
  # albums or only songs. Two queries however many reviews there are: one
  # grouped average, one for the releases.
  class Ranking
    LIMIT = 10
    # One enthusiastic 10/10 shouldn't top the chart.
    MIN_SCORES = 2
    # "Топ альбомів", "Дно пісень".
    KIND_LABELS = { "album" => "альбомів", "song" => "пісень" }.freeze

    # kind: "album" or "song", or nil for both.
    def initialize(chat:, best:, kind: nil, range: nil, label: "весь час")
      @chat = chat
      @best = best
      @kind = kind
      @range = range
      @label = label
    end

    def text
      rows = scored_releases
      header = [ @best ? "🏆 Топ" : "🗑 Дно", KIND_LABELS[@kind], "за #{@label}:" ].compact.join(" ")
      return "#{header}\n\nПоки нема релізів з #{MIN_SCORES} і більше оцінками." if rows.empty?

      releases = Release.where(id: rows.map(&:first)).index_by(&:id)
      lines = rows.each_with_index.map do |(release_id, average, count), index|
        "#{index + 1}. #{Formatting.release(releases.fetch(release_id))} · " \
          "#{Formatting.score(average)} (#{Plural.count(count, 'оцінка', 'оцінки', 'оцінок')})"
      end

      "#{header}\n\n#{lines.join("\n")}"
    end

    private

    # [[release_id, average, count], ...], best (or worst) first. Ties go to
    # the release with more scores.
    def scored_releases
      direction = @best ? "DESC" : "ASC"
      reviews = Review.where(chat: @chat).where.not(score: nil)
      reviews = reviews.where(release_id: @chat.release_shares.where(shared_at: @range).select(:release_id)) if @range
      reviews = reviews.where(release_id: Release.where(kind: @kind).select(:id)) if @kind

      reviews.group(:release_id)
        .having("COUNT(*) >= ?", MIN_SCORES)
        .order(Arel.sql("AVG(score) #{direction}, COUNT(*) DESC, release_id"))
        .limit(LIMIT)
        .pluck(:release_id, Arel.sql("AVG(score)"), Arel.sql("COUNT(*)"))
    end
  end
end
