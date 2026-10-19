module Camerton
  # "@bot жанри": the Discogs genres and styles of the releases shared in
  # this chat, the most releases first. A release counts once per genre or
  # style however often it was shared. Styles are many (hundreds once the
  # chat has shared enough), so only the top ones are listed: a Telegram
  # message holds 4096 characters. Three queries however many releases.
  class Genres
    STYLES_SHOWN = 20
    # Whole SQL fragments, not a column name spliced in: nothing to inject.
    GENRE_TAGS = "CROSS JOIN LATERAL unnest(releases.genres) AS tag".freeze
    STYLE_TAGS = "CROSS JOIN LATERAL unnest(releases.styles) AS tag".freeze

    def initialize(chat:)
      @chat = chat
    end

    def text
      genres = counts(GENRE_TAGS)
      return "🎸 Жанри:\n\nЩе нема релізів із жанром з Discogs." if genres.empty?

      [ "🎸 Жанри наших релізів:", "", *lines(genres), *without_genre, *styles_section ].join("\n")
    end

    private

    # [[tag, releases count]], the most releases first, then by name.
    def counts(tags_join)
      Release.where(id: shared_ids)
        .joins(tags_join)
        .group("tag")
        .order(Arel.sql("COUNT(DISTINCT releases.id) DESC, tag"))
        .pluck(Arel.sql("tag"), Arel.sql("COUNT(DISTINCT releases.id)"))
    end

    def lines(rows)
      rows.map { |tag, count| "#{tag}: #{releases(count)}" }
    end

    def without_genre
      count = Release.where(id: shared_ids).where("COALESCE(cardinality(releases.genres), 0) = 0").count
      count.positive? ? [ "", "Без жанру: #{releases(count)}" ] : []
    end

    def styles_section
      styles = counts(STYLE_TAGS)
      return [] if styles.empty?

      section = [ "", "🎛 Стилі:", "", *lines(styles.first(STYLES_SHOWN)) ]
      section << "і ще #{Formatting.count(styles.size - STYLES_SHOWN, 'стиль', 'стилі', 'стилів')}" if styles.size > STYLES_SHOWN
      section
    end

    def releases(count)
      Formatting.count(count, "реліз", "релізи", "релізів")
    end

    def shared_ids
      @chat.release_shares.select(:release_id)
    end
  end
end
