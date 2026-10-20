module Achievements
  # What every achievement answers. Subclasses define code, title,
  # description, period_kind and winner_ids(chat, period), each in a fixed
  # number of queries however many members the chat has.
  class Rule
    # Hidden in "ачівки" as "???" until someone in the chat earns it.
    def secret?
      false
    end

    # The goal of a counting rule ("17/42" in "мої ачівки"), or nil.
    def goal
      nil
    end

    # { user_id => count so far } for a counting rule; empty otherwise.
    def counts(_chat, _period)
      {}
    end
  end
end
