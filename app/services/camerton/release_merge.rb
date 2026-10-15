module Camerton
  # Two links to the same song or album (another upload of it, a lyric
  # video) are one release. Once a release is resolved, it merges into the
  # oldest other release of the same kind, artist and title (ignoring case
  # and surrounding spaces): its shares and reviews move there, and it stays
  # behind only to map its link (merged_into).
  #
  # A member who reviewed both keeps one review: the messages are joined and
  # the review is re-scored from all of them, silently.
  class ReleaseMerge
    def initialize(release)
      @release = release
    end

    # The release this one would merge into, or nil.
    def target
      return unless @release.resolved? && @release.merged_into_id.nil? && @release.artist.present? && @release.title.present?

      Release.where(kind: @release.kind, status: :resolved, merged_into_id: nil)
        .where.not(id: @release.id)
        .where("LOWER(TRIM(artist)) = ? AND LOWER(TRIM(title)) = ?", normalized(@release.artist), normalized(@release.title))
        .order(:id)
        .first
    end

    # Returns the release merged into, or nil when there was nothing to merge.
    def call
      to_rescore = []

      merged_into = Release.transaction do
        # Two duplicates resolving at once would each see the other as the
        # target; one at a time per name, they merge one way.
        lock_name
        @release.reload
        next unless (found = target)

        @release.shares.update_all(release_id: found.id, updated_at: Time.current)
        to_rescore = move_reviews(found)
        @release.update!(merged_into: found)
        found
      end

      to_rescore.each { |review| ScoreReviewJob.perform_later(review, react: false) }
      merged_into
    end

    private

    # Returns the reviews that gained messages and need a new score.
    def move_reviews(found)
      @release.reviews.to_a.filter_map do |review|
        kept = Review.find_by(chat_id: review.chat_id, user_id: review.user_id, release: found)
        if kept
          review.messages.update_all(review_id: kept.id, updated_at: Time.current)
          review.destroy!
          kept
        else
          review.update!(release: found)
          nil
        end
      end
    end

    def lock_name
      key = [ "camerton_release", @release.kind, normalized(@release.artist), normalized(@release.title) ].join(":")
      Release.connection.execute(Release.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtext(?))", key ]))
    end

    def normalized(name)
      name.to_s.strip.downcase
    end
  end
end
