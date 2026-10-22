module Achievements
  module Rules
    # Серія: scoring something every Kyiv day, at least MIN_DAYS in a row.
    # Awarded and followed by Achievements::Streaks, not the checker: a
    # streak ends rather than being taken back.
    class Streak < Rule
      MIN_DAYS = 3

      attr_reader :code, :title

      def initialize(code:, title:)
        @code = code
        @title = title
      end

      def period_kind
        :streak
      end

      def decided_by
        :streaks
      end

      def description
        "оцінки #{MIN_DAYS}+ дні поспіль"
      end

      # The lengths announced on the way: 3, 7, 10, then every 5 days.
      def milestone?(days)
        [ 3, 7 ].include?(days) || (days >= 10 && (days % 5).zero?)
      end

      def days(count)
        Plural.count(count, "день", "дні", "днів")
      end
    end
  end
end
