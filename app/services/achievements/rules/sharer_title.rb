module Achievements
  module Rules
    # Найшанованіший / Найзневаженіший камертон тижня: the best or worst
    # average score of the releases a member shared this week, from at
    # least MIN_RELEASES of them. Every score counts, whenever it came and
    # the sharer's own included, as in "@bot камертони".
    class SharerTitle < Title
      MIN_RELEASES = 2

      def initialize(code:, title:, worst:, secret: false)
        super(code: code, title: title, secret: secret)
        @worst = worst
      end

      def period_kind
        :week
      end

      def description
        "#{@worst ? 'найнижча' : 'найвища'} середня оцінка релізів, скинутих за тиждень (від #{MIN_RELEASES})"
      end

      private

      def lowest?
        @worst
      end

      # Averages rounded to a hundredth, so float noise can't split a tie.
      def values(chat, period)
        pairs = chat.release_shares.where(shared_at: period.range).select(:user_id, :release_id).distinct
        scores = ActiveRecord::Base.sanitize_sql_array([
          "JOIN reviews ON reviews.release_id = pairs.release_id AND reviews.chat_id = ? AND reviews.score IS NOT NULL",
          chat.id
        ])

        ReleaseShare.unscoped.from(pairs, :pairs).joins(scores).group("pairs.user_id")
          .having("COUNT(DISTINCT pairs.release_id) >= ?", MIN_RELEASES)
          .pluck(Arel.sql("pairs.user_id"), Arel.sql("ROUND(AVG(reviews.score), 2)"))
          .to_h
      end
    end
  end
end
