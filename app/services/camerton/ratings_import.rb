module Camerton
  # Scores from a member's ratings spreadsheet, for releases that may never
  # have been shared in the chat. Each rating names a YouTube Music link,
  # the artist and title as the member wrote them, and a score.
  #
  # The release is the link's, created resolved with those names if new,
  # then merged like any resolved release (ReleaseMerge): an album the chat
  # already has under another link keeps the score. No shares are created,
  # so imported releases stay out of the digest and "що послухати".
  #
  # Silent: no messages, reactions or AI calls. Only fills a review with no
  # score; a score from the chat is never replaced. The review's source is
  # spreadsheet unless the chat shared the release (Review#source).
  # Safe to run again. A dry run rolls everything back.
  class RatingsImport
    Rating = Data.define(:url, :artist, :title, :year, :score)
    Report = Data.define(:releases_created, :releases_merged, :reviews_created, :reviews_filled, :skipped)

    def initialize(chat:, user:, ratings:, dry_run: true)
      @chat = chat
      @user = user
      @ratings = ratings
      @dry_run = dry_run
      @skipped = Hash.new { |hash, key| hash[key] = [] }
    end

    def call
      report = nil
      # requires_new: see HistoryImport#call.
      ActiveRecord::Base.transaction(requires_new: true) do
        report = import
        raise ActiveRecord::Rollback if @dry_run
      end
      report
    end

    private

    def import
      counts = Hash.new(0)

      @ratings.each do |rating|
        link = Links.first_in({ text: rating.url })
        next skip(:invalid_links, rating) unless link
        next skip(:invalid_scores, rating) unless rating.score.is_a?(Integer) && (1..10).cover?(rating.score)

        release = Release.find_for(link) || create_release(link, rating, counts)
        review = Review.find_or_initialize_by(chat: @chat, release: release, user: @user)
        next skip(:already_scored, rating) if review.score

        counts[review.new_record? ? :reviews_created : :reviews_filled] += 1
        source = @chat.release_shares.exists?(release: release) ? :telegram : :spreadsheet
        review.update!(score: rating.score, source: source, scored_at: Time.current)
      end

      Report.new(
        releases_created: counts[:releases_created], releases_merged: counts[:releases_merged], reviews_created: counts[:reviews_created],
        reviews_filled: counts[:reviews_filled], skipped: @skipped.transform_values(&:dup)
      )
    end

    # The new release, or the existing one of the same name it merged into.
    def create_release(link, rating, counts)
      release = Release.create!(
        platform: link.platform, external_id: link.external_id, kind: link.kind, url: link.url,
        status: :resolved, artist: rating.artist, title: rating.title, year: rating.year
      )
      merged_into = ReleaseMerge.new(release).call
      counts[merged_into ? :releases_merged : :releases_created] += 1
      merged_into || release
    end

    # "Artist — Title" by reason.
    def skip(reason, rating)
      @skipped[reason] << "#{rating.artist} — #{rating.title}"
      nil
    end
  end
end
