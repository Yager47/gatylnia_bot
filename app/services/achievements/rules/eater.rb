module Achievements
  module Rules
    # Пісенний Пожирач, Альбомний Пожирач and Пожирач: scored every song,
    # every album, or both, shared in the chat this week, your own shares
    # included. A kind counts only with at least MIN_RELEASES of it shared.
    # Whoever earns both gets only Пожирач, so each rule takes the members
    # who earned exactly its kinds.
    class Eater < Rule
      MIN_RELEASES = 2
      KINDS = %w[song album].freeze
      WHAT = { %w[song] => "усі пісні", %w[album] => "усі альбоми", KINDS => "усі пісні й альбоми" }.freeze

      attr_reader :code, :title

      def initialize(code:, title:, kinds:)
        @code = code
        @title = title
        @kinds = kinds.map(&:to_s).sort.reverse
      end

      def period_kind
        :week
      end

      def decided_by
        :closer
      end

      def description
        "оцінені #{WHAT.fetch(@kinds)}, скинуті за тиждень (від #{MIN_RELEASES})"
      end

      # Two queries per kind.
      def winner_ids(chat, period)
        eaters = KINDS.index_with { |kind| eaters(chat, period, kind) }
        others = KINDS - @kinds

        @kinds.map { |kind| eaters.fetch(kind) }.reduce(:&) - others.flat_map { |kind| eaters.fetch(kind) }
      end

      private

      # Members who scored every release of the kind shared this week.
      def eaters(chat, period, kind)
        release_ids = chat.release_shares.where(shared_at: period.range)
          .joins(:release).where(releases: { kind: kind }).distinct.pluck(:release_id)
        return [] if release_ids.size < MIN_RELEASES

        Review.where(chat: chat, release_id: release_ids).where.not(score: nil)
          .group(:user_id).having("COUNT(*) = ?", release_ids.size)
          .pluck(:user_id)
      end
    end
  end
end
