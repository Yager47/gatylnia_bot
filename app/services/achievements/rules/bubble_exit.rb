module Achievements
  module Rules
    # Вихід з бульбашки: scoring a release with a Discogs style the member
    # never scored before, `goal` times this week. Releases Discogs didn't
    # match have no styles and never count.
    class BubbleExit < Counting
      NEW_STYLE = <<~SQL.squish.freeze
        EXISTS (
          SELECT 1 FROM unnest(releases.styles) AS new_styles(name)
          WHERE NOT EXISTS (
            SELECT 1 FROM reviews earlier
            JOIN releases earlier_releases ON earlier_releases.id = earlier.release_id
            WHERE earlier.chat_id = reviews.chat_id
              AND earlier.user_id = reviews.user_id
              AND earlier.score IS NOT NULL
              AND new_styles.name = ANY(earlier_releases.styles)
              AND (SELECT MIN(review_messages.sent_at) FROM review_messages
                   WHERE review_messages.review_id = earlier.id) < firsts.first_at
          )
        )
      SQL

      def period_kind
        :week
      end

      def description
        "#{goal_count('оцінка', 'оцінки', 'оцінок')} #{per_period} у нових для тебе стилях (Discogs)"
      end

      def counts(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .joins(:release).where(NEW_STYLE)
          .group(:user_id).count
      end
    end
  end
end
