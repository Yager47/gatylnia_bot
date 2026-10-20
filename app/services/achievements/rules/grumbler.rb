module Achievements
  module Rules
    # Буркотун (secret): the most bad scores (1–3) given this month.
    class Grumbler < Title
      def period_kind
        :month
      end

      def description
        "найбільше оцінок 1–3 за місяць"
      end

      private

      def values(chat, period)
        Reviews.first_sent_in(chat, period.range).where(score: Review::LABELS[:bad]).group(:user_id).count
      end
    end
  end
end
