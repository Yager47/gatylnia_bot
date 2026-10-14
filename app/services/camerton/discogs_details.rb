module Camerton
  # Adds Discogs' year, genres and album to a resolved release before it's
  # announced. Extra info only: a failure is logged and the release is
  # announced without it, never retried, so Discogs can't hold up a reply.
  class DiscogsDetails
    def initialize(release, discogs: Discogs.new)
      @release = release
      @discogs = discogs
    end

    # Asks Discogs once per release: a re-share or a job retry finds
    # discogs_checked_at set, even when nothing matched.
    def call
      return unless @release.resolved? && @release.artist.present? && @release.discogs_checked_at.nil?

      result = DiscogsLookup.new(@release, discogs: @discogs).call
      @release.update!(discogs_checked_at: Time.current, **attributes(result))
    rescue Discogs::Error, JSON::ParserError => e
      Rails.logger.warn("[Camerton::DiscogsDetails] Release #{@release.id}: #{e.class}: #{e.message}")
    end

    private

    def attributes(result)
      return {} unless result

      {
        discogs_master_id: result.master_id,
        year: result.year,
        album_title: result.album_title,
        genres: result.genres,
        styles: result.styles
      }
    end
  end
end
