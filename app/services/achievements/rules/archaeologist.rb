module Achievements
  module Rules
    # Археолог: scoring a release someone else shared more than DAYS days
    # earlier (after the daily reminder gave up on it), `goal` times this week.
    class Archaeologist < Counting
      DAYS = 7

      def period_kind
        :week
      end

      def description
        "#{goal_count('оцінка', 'оцінки', 'оцінок')} #{per_period} релізам, скинутим понад #{DAYS} днів тому"
      end

      def counts(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .joins(Reviews::FIRST_SHARE).where(Reviews::NOT_OWN_SHARE)
          .where("firsts.first_at >= first_shares.shared_at + make_interval(days => ?)", DAYS)
          .group(:user_id).count
      end
    end
  end
end
