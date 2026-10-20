module Achievements
  module Rules
    # Жанровий турист: scored releases in `goal` different Discogs styles
    # this month.
    class GenreTourist < Counting
      def period_kind
        :month
      end

      def description
        "#{goal_count('різний стиль', 'різні стилі', 'різних стилів')} (Discogs) #{per_period}"
      end

      def counts(chat, period)
        styles = Reviews.first_sent_in(chat, period.range).joins(:release)
          .select("reviews.user_id, unnest(releases.styles) AS style")
        Review.from(styles, :styles).group("styles.user_id").distinct.count("styles.style")
      end
    end
  end
end
