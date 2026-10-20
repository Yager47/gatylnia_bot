module Achievements
  module Rules
    # Пісенний Марафонець and Напівмарафонець: at least `goal` songs scored
    # this month. Each is its own achievement, so both can be won.
    class SongMarathon < Rule
      attr_reader :code, :title, :goal

      def initialize(code:, title:, goal:)
        @code = code
        @title = title
        @goal = goal
      end

      def period_kind
        :month
      end

      # "21 оцінена пісня за місяць"
      def description
        "#{Camerton::Formatting.count(goal, 'оцінена пісня', 'оцінені пісні', 'оцінених пісень')} за місяць"
      end

      def winner_ids(chat, period)
        counts(chat, period).select { |_user_id, count| count >= goal }.keys
      end

      # One query, however many members.
      def counts(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .joins(:release).where(releases: { kind: :song })
          .group(:user_id).count
      end
    end
  end
end
