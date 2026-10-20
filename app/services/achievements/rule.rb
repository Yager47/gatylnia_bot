module Achievements
  # What every achievement answers. Subclasses define code, title,
  # description, period_kind and winner_ids(chat, period) (or levels), each
  # in a fixed number of queries however many members the chat has.
  class Rule
    # Hidden in "ачівки" as "???" until someone in the chat earns it.
    def secret?
      false
    end

    # Decided once its week or month is over (Achievements::Closer) rather
    # than as soon as someone qualifies.
    def period_end?
      false
    end

    # The goal of a counting rule ("17/42" in "мої ачівки"), or nil.
    def goal
      nil
    end

    # The periods a check at `at` decides: the week or month it falls in.
    def periods(_chat, at)
      [ Period.current(period_kind, now: at) ]
    end

    # { user_id => count so far } for a counting rule; empty otherwise.
    def counts(_chat, _period)
      {}
    end

    # { user_id => level } of everyone who qualifies. A plain achievement
    # has no levels (nil); one that grows overrides this and level_line.
    def levels(chat, period)
      winner_ids(chat, period).index_with(nil)
    end

    # The chat's announcement of a change: :awarded, :revoked, or :leveled
    # (an achievement held already went up to `level`). Telegram HTML;
    # `mention` is escaped already; period_key names what it's for.
    def line(change, mention, level, period_key: nil)
      case change
      when :awarded then "🏆 #{mention} отримує ачівку «#{title}»: #{description}"
      when :revoked then "↩️ #{mention} втрачає ачівку «#{title}»: вже не #{description}"
      when :leveled then level_line(mention, level)
      end
    end

    private

    def level_line(_mention, _level)
      raise NotImplementedError, "#{self.class} has no levels"
    end
  end
end
