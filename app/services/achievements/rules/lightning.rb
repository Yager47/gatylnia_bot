module Achievements
  module Rules
    # Блискавка: scoring a release someone else shared within an hour of the
    # share, `goal` times this week.
    class Lightning < Counting
      def period_kind
        :week
      end

      def description
        "#{goal_count('оцінка', 'оцінки', 'оцінок')} #{per_period} протягом години після посилання"
      end

      def counts(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .joins(Reviews::FIRST_SHARE).where(Reviews::NOT_OWN_SHARE)
          .where("firsts.first_at <= first_shares.shared_at + interval '1 hour'")
          .group(:user_id).count
      end
    end
  end
end
