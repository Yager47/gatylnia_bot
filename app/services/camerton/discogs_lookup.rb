module Camerton
  # Finds a release's original year and genres on Discogs, and for a song the
  # studio album it first came out on. Two requests: a search for masters
  # (Discogs groups every pressing and reissue of a record under one master),
  # then the chosen master for its year, genres and styles.
  class DiscogsLookup
    Result = Data.define(:master_id, :year, :album_title, :genres, :styles)

    # Version labels that aren't part of the name on Discogs:
    # "Uptown Top Ranking (Remastered 2001)", "Jezebel [Live]".
    TRAILING_LABELS = /(\s*[(\[][^)\]]*[)\]])+\z/
    # A genre that says nothing about the music (sermons, interviews).
    IGNORED_GENRES = [ "Non-Music" ].freeze

    def initialize(release, discogs: Discogs.new)
      @release = release
      @discogs = discogs
    end

    # Nil when Discogs has no matching master.
    def call
      candidate = pick(@discogs.search_masters(**search_params))
      return unless candidate

      master = @discogs.master(candidate["id"])
      return unless master

      Result.new(
        master_id: master["id"],
        year: master["year"].to_i.nonzero?,
        album_title: album_title(candidate, master),
        genres: Array(master["genres"]) - IGNORED_GENRES,
        styles: Array(master["styles"])
      )
    end

    private

    def search_params
      { artist: @release.artist }.merge(@release.album? ? { release_title: bare_title } : { track: bare_title })
    end

    def bare_title
      @bare_title ||= @release.title.sub(TRAILING_LABELS, "").presence || @release.title
    end

    # The earliest master, skipping compilations, and bootlegs unless there's
    # nothing official. For a song, albums go before singles and EPs. Discogs'
    # top hit for a well-known song is often a later single, not the album
    # ("Bohemian Rhapsody" => a 1992 cassette single).
    def pick(results)
      results = results.reject { |result| format?(result, "Compilation") }
      results = prefer(results) { |result| !format?(result, "Unofficial Release") }
      results = prefer(results) { |result| format?(result, "Album") } if @release.song?

      results.select { |result| result["year"].to_i.positive? }.min_by { |result| result["year"].to_i } || results.first
    end

    def prefer(results, &)
      results.select(&).presence || results
    end

    def format?(result, name)
      Array(result["format"]).include?(name)
    end

    # Only for a song on an album, and not when the album is named after it.
    def album_title(candidate, master)
      return unless @release.song? && format?(candidate, "Album")

      master["title"] unless master["title"].to_s.casecmp?(bare_title)
    end
  end
end
