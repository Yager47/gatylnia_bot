module Camerton
  # Two links to the same song or album (another upload of it, a lyric
  # video) are one release. Once a release is resolved, it merges into the
  # oldest other release of the same kind, artist and title (ignoring case
  # and surrounding spaces): its shares and reviews move there, and it stays
  # behind only to map its link (merged_into). A remaster, a dated remix or
  # a deluxe edition of the album is the same release: "Revolver (Remastered
  # 2009)", "Let It Be (2021 Mix)" and "Exciter (Deluxe)" match "Revolver",
  # "Let It Be" and "Exciter", while "(Some DJ Mix)" stays a release of its
  # own.
  #
  # A member who reviewed both keeps one review: the messages are joined and
  # the review is re-scored from all of them, silently.
  class ReleaseMerge
    # A trailing "(…)", "[…]" or " - …" note on a title.
    TITLE_NOTE = /\s*(?:\((?<note>[^()]*)\)|\[(?<note>[^\[\]]*)\]|\s-\s(?<note>[^-]+))\z/
    # Notes that only mark another edition.
    EDITION_NOTE = /\A(?:
      (?:\d{4}\s+)?(?:digital(?:ly)?\s+)?remaster(?:ed)?(?:\s+\d{4})?(?:\s+(?:version|edition))? # Remastered 2009, 2009 Remaster
      | \d{4}\s+(?:re-?)?mix                                                                     # 2021 Mix, 2021 Remix
      | (?:\d{4}\s+|\d+(?:st|nd|rd|th)\s+anniversary\s+)?(?:super\s+)?deluxe(?:\s+(?:edition|version))? # Deluxe, 50th Anniversary Super Deluxe Edition
    )\z/xi

    # The title without edition notes, for comparing.
    def self.base_title(title)
      title = title.to_s.strip
      while (match = TITLE_NOTE.match(title)) && EDITION_NOTE.match?(match[:note].strip)
        title = match.pre_match.strip
      end
      title.downcase
    end

    def initialize(release)
      @release = release
    end

    # The release this one would merge into, or nil.
    def target
      return unless @release.resolved? && @release.merged_into_id.nil? && @release.artist.present? && @release.title.present?

      # Same artist in SQL, then the titles here: an artist has few releases.
      title = self.class.base_title(@release.title)
      Release.where(kind: @release.kind, status: :resolved, merged_into_id: nil)
        .where.not(id: @release.id)
        .where("LOWER(TRIM(artist)) = ?", normalized(@release.artist))
        .order(:id)
        .find { |release| self.class.base_title(release.title) == title }
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
      # A member who reviewed both now has one review instead of two.
      Chat.where(id: to_rescore.map(&:chat_id).uniq).each { |chat| CheckAchievementsJob.perform_later(chat) }
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
      key = [ "camerton_release", @release.kind, normalized(@release.artist), self.class.base_title(@release.title) ].join(":")
      Release.connection.execute(Release.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtext(?))", key ]))
    end

    def normalized(name)
      name.to_s.strip.downcase
    end
  end
end
