module Achievements
  module Rules
    # Перевзувач (secret): changing your own score of a release this week.
    # The first change earns it; every further one is announced with the
    # week's count, and removing the reviews takes it back.
    class Turncoat < Rule
      attr_reader :code, :title

      def initialize(code:, title:)
        @code = code
        @title = title
      end

      def period_kind
        :week
      end

      def secret?
        true
      end

      def description
        "змінена оцінка цього тижня"
      end

      def levels(chat, period)
        ReviewScoreChange.joins(:review)
          .where(reviews: { chat_id: chat.id }, changed_at: period.range)
          .group("reviews.user_id").count
      end

      def winner_ids(chat, period)
        levels(chat, period).keys
      end

      def line(change, mention, level, period_key: nil)
        return "↩️ #{mention} втрачає ачівку «#{title}»: змін оцінок цього тижня не лишилось" if change == :revoked

        super
      end

      private

      # "🔄 @olya перевзувається: 2 рази цього тижня"
      def level_line(mention, level)
        "🔄 #{mention} перевзувається: #{Plural.count(level, 'раз', 'рази', 'разів')} цього тижня"
      end
    end
  end
end
