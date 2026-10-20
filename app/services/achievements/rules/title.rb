module Achievements
  module Rules
    # A title for whoever is best at something over a closed week or month,
    # decided once it ends (Achievements::Closer). Members tied for the best
    # value share it.
    class Title < Rule
      attr_reader :code, :title

      def initialize(code:, title:, secret: false)
        @code = code
        @title = title
        @secret = secret
      end

      def secret?
        @secret
      end

      def period_end?
        true
      end

      def winner_ids(chat, period)
        values = values(chat, period)
        return [] if values.empty?

        best = lowest? ? values.values.min : values.values.max
        values.select { |_user_id, value| value == best }.keys
      end

      private

      # { user_id => value } of the members in the running; one query.
      def values(_chat, _period)
        raise NotImplementedError
      end

      # Whether the lowest value wins rather than the highest.
      def lowest?
        false
      end
    end
  end
end
