module Achievements
  module Rules
    # Пісенний Марафонець and Напівмарафонець: at least `goal` songs scored
    # this month. Each is its own achievement, so both can be won.
    class SongMarathon
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

      # One query, however many members.
      def winner_ids(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .joins(:release).where(releases: { kind: :song })
          .group(:user_id).having("COUNT(*) >= ?", goal)
          .pluck(:user_id)
      end
    end
  end
end
