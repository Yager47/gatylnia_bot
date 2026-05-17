class TelegramReaction
  class << self
    def emoji(reaction_type)
      data = reaction_type.with_indifferent_access

      case data[:type]
      when "emoji" then data[:emoji]
      when "custom_emoji" then "custom_emoji:#{data[:custom_emoji_id]}"
      when "paid" then "paid"
      else "?"
      end
    end

    def emojis(reaction_types)
      Array(reaction_types).map { |reaction| emoji(reaction) }
    end
  end
end
