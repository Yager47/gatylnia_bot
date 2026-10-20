module Achievements
  module Rules
    # An achievement for reaching `goal` of something within a week or a
    # month. Subclasses define period_kind, description and counts, one
    # query however many members.
    class Counting < Rule
      PER_PERIOD = { week: "за тиждень", month: "за місяць" }.freeze

      attr_reader :code, :title, :goal

      def initialize(code:, title:, goal:)
        @code = code
        @title = title
        @goal = goal
      end

      def winner_ids(chat, period)
        counts(chat, period).select { |_user_id, count| count >= goal }.keys
      end

      private

      def per_period
        PER_PERIOD.fetch(period_kind)
      end

      # "5 оцінок", "21 оцінена пісня"
      def goal_count(one, few, many)
        Camerton::Formatting.count(goal, one, few, many)
      end
    end
  end
end
