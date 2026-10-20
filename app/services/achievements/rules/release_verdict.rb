module Achievements
  module Rules
    # Одностайність and Розкол: how far apart the chat's scores of a release
    # are, decided once it's AGE old (when the daily reminder stops asking),
    # for whoever shared it in the chat first. Needs at least MIN_SCORES
    # scores, the sharer's own included.
    class ReleaseVerdict < Rule
      AGE = 7.days
      MIN_SCORES = 2

      attr_reader :code, :title

      # spread: the range of highest-minus-lowest that earns it.
      def initialize(code:, title:, spread:, wording:, secret: false)
        @code = code
        @title = title
        @spread = spread
        @wording = wording
        @secret = secret
      end

      def secret?
        @secret
      end

      def period_kind
        :release
      end

      def decided_by
        :closer
      end

      def description
        "оцінки твого релізу #{@wording} (від #{MIN_SCORES} оцінок, через тиждень після посилання)"
      end

      # The releases first shared in the chat AGE ago, on that Kyiv day. A
      # daily run sees each once; a retry the same day sees the same ones.
      def periods(chat, at)
        day = (at - AGE).all_day
        chat.release_shares.group(:release_id).having("MIN(shared_at) BETWEEN ? AND ?", day.begin, day.end)
          .pluck(:release_id).map { |release_id| ReleasePeriod.new(release_id) }
      end

      # Two queries per release: few are a week old on any one day.
      def winner_ids(chat, period)
        low, high, count = Review.where(chat: chat, release_id: period.release_id).where.not(score: nil)
          .pick(Arel.sql("MIN(score)"), Arel.sql("MAX(score)"), Arel.sql("COUNT(*)"))
        return [] if count < MIN_SCORES || !@spread.cover?(high - low)

        [ chat.release_shares.where(release_id: period.release_id).order(:shared_at, :id).pick(:user_id) ]
      end

      # Names the release: "🏆 @olya отримує ачівку «Розкол» за 🎵 Queen —
      # Bohemian Rhapsody: оцінки розійшлися на 6+ балів".
      def line(change, mention, _level, period_key:)
        release = Release.find(period_key.delete_prefix("release-"))
        name = ERB::Util.html_escape(Camerton::Formatting.release(release))
        return "↩️ #{mention} втрачає ачівку «#{title}» за #{name}" if change == :revoked

        "🏆 #{mention} отримує ачівку «#{title}» за #{name}: оцінки #{@wording}"
      end
    end
  end
end
