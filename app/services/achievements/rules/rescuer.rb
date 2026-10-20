module Achievements
  module Rules
    # Рятувальник: the first score of a release nobody had scored for
    # DAYS days after the share, `goal` times this week.
    class Rescuer < Counting
      DAYS = 3

      def period_kind
        :week
      end

      def description
        "#{goal_count('реліз', 'релізи', 'релізів')} #{per_period}, які до тебе #{DAYS}+ дні ніхто не оцінив"
      end

      def counts(chat, period)
        Reviews.ranked(chat)
          .where("ranked.first_at = ranked.release_first_at")
          .where("ranked.first_at >= ranked.shared_at + make_interval(days => ?)", DAYS)
          .where("ranked.first_at" => period.range)
          .group("ranked.user_id").count
      end
    end
  end
end
