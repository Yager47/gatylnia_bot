module Achievements
  module Rules
    # Перший слухач: the first in the chat to score a release someone else
    # shared, `goal` times this week.
    class FirstListener < Counting
      def period_kind
        :week
      end

      def description
        "#{goal_count('реліз', 'релізи', 'релізів')} #{per_period}, де твоя оцінка перша"
      end

      def counts(chat, period)
        Reviews.ranked(chat)
          .where("ranked.first_at = ranked.release_first_at")
          .where("ranked.first_at" => period.range)
          .group("ranked.user_id").count
      end
    end
  end
end
