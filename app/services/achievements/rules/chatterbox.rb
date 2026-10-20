module Achievements
  module Rules
    # Базікало: reviews with a voice message or a video note among their
    # messages, `goal` this month.
    class Chatterbox < Counting
      def period_kind
        :month
      end

      def description
        "#{goal_count('оцінка', 'оцінки', 'оцінок')} голосовим чи кружечком #{per_period}"
      end

      def counts(chat, period)
        spoken = ReviewMessage.where("review_messages.review_id = reviews.id")
          .where(source: %i[voice video_note])
        Reviews.first_sent_in(chat, period.range).where(spoken.arel.exists).group(:user_id).count
      end
    end
  end
end
