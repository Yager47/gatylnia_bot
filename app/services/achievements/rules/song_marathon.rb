module Achievements
  module Rules
    # Пісенний Марафонець and Напівмарафонець: songs scored this month. Each
    # is its own achievement, so both can be won.
    class SongMarathon < Counting
      def period_kind
        :month
      end

      # "21 оцінена пісня за місяць"
      def description
        "#{goal_count('оцінена пісня', 'оцінені пісні', 'оцінених пісень')} #{per_period}"
      end

      def counts(chat, period)
        Reviews.first_sent_in(chat, period.range)
          .joins(:release).where(releases: { kind: :song })
          .group(:user_id).count
      end
    end
  end
end
