module Achievements
  module Rules
    # Некромант: sharing releases Discogs dates before YEAR, `goal` different
    # ones this week. Releases without a Discogs year never count.
    class Necromancer < Counting
      YEAR = 1980

      def period_kind
        :week
      end

      def description
        "#{goal_count('скинутий реліз', 'скинуті релізи', 'скинутих релізів')} #{per_period}, виданих до #{YEAR} року"
      end

      def counts(chat, period)
        chat.release_shares.where(shared_at: period.range)
          .joins(:release).where("releases.year < ?", YEAR)
          .group(:user_id).distinct.count(:release_id)
      end
    end
  end
end
