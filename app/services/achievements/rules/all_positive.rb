module Achievements
  module Rules
    # Всеїдний: at least MIN_REVIEWS scores this week, every one of them 8–10.
    class AllPositive < Rule
      MIN_REVIEWS = 3
      LOWEST = 8

      attr_reader :code, :title

      def initialize(code:, title:)
        @code = code
        @title = title
      end

      def period_kind
        :week
      end

      def period_end?
        true
      end

      def description
        "від #{MIN_REVIEWS} оцінок за тиждень, і всі #{LOWEST}–10"
      end

      def winner_ids(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .group(:user_id).having("COUNT(*) >= ? AND MIN(reviews.score) >= ?", MIN_REVIEWS, LOWEST)
          .pluck(:user_id)
      end
    end
  end
end
