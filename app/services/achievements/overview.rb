module Achievements
  # "@bot ачівки" / "@bot досягнення": every achievement there is, and how
  # many members of this chat have ever earned it. A secret one shows as
  # "???" until someone here earns it. Two queries.
  #   🏆 Ачівки:
  #
  #   • Пісенний Марафонець — 42 оцінені пісні за місяць · здобули 2 з 6
  #   • ??? — секретна ачівка
  class Overview
    def initialize(chat:, rules: RULES)
      @chat = chat
      @rules = rules
    end

    def text
      earners = @chat.achievements.active.where(code: @rules.map(&:code)).group(:code).distinct.count(:user_id)
      members = @chat.chat_users.count

      lines = @rules.map do |rule|
        earned = earners.fetch(rule.code, 0)
        if rule.secret? && earned.zero?
          "• ??? — секретна ачівка"
        else
          "• #{rule.title} — #{rule.description} · #{rarity(earned, members)}"
        end
      end

      [ "🏆 Ачівки:", lines.join("\n"), "Твої — #{BotMention.text} мої ачівки" ].join("\n\n")
    end

    private

    def rarity(earned, members)
      earned.zero? ? "ще ніхто" : "здобули #{earned} з #{[ earned, members ].max}"
    end
  end
end
