module Achievements
  module Rules
    # Не такий як всі (secret): scores furthest from everyone else's this
    # month. For each release, the gap between the member's score and the
    # average of the others' (theirs left out, or it would pull the average
    # their way), averaged over at least MIN_RELEASES releases with at least
    # MIN_OTHERS other scores each.
    class Contrarian < Title
      MIN_RELEASES = 8
      MIN_OTHERS = 2

      OTHERS = <<~SQL.squish.freeze
        JOIN LATERAL (
          SELECT AVG(others.score) AS average, COUNT(*) AS scores
          FROM reviews others
          WHERE others.chat_id = reviews.chat_id
            AND others.release_id = reviews.release_id
            AND others.user_id <> reviews.user_id
            AND others.score IS NOT NULL
        ) others ON true
      SQL

      def period_kind
        :month
      end

      def description
        "оцінки найдальші від решти за місяць (від #{MIN_RELEASES} релізів)"
      end

      private

      def values(chat, period)
        Reviews.first_sent_in(chat, period.range).joins(OTHERS)
          .where("others.scores >= ?", MIN_OTHERS)
          .group(:user_id).having("COUNT(*) >= ?", MIN_RELEASES)
          .pluck(:user_id, Arel.sql("ROUND(AVG(ABS(reviews.score - others.average)), 2)"))
          .to_h
      end
    end
  end
end
