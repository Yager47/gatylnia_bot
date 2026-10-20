module Achievements
  module Rules
    # Розгорнутий критик: reviews of at least LENGTH characters in all
    # (voice and video notes by their transcripts), `goal` this week.
    class LongCritic < Counting
      LENGTH = 300

      def period_kind
        :week
      end

      def description
        "#{goal_count('оцінка', 'оцінки', 'оцінок')} #{per_period} від #{LENGTH} символів"
      end

      def counts(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .where(<<~SQL.squish, LENGTH)
            (SELECT SUM(char_length(review_messages.text)) FROM review_messages
             WHERE review_messages.review_id = reviews.id) >= ?
          SQL
          .group(:user_id).count
      end
    end
  end
end
