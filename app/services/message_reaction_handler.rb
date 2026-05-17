class MessageReactionHandler
  def initialize(update, count_mode: false)
    @update = update.with_indifferent_access
    @count_mode = count_mode
  end

  def call
    chat = Chat.find_by(telegram_id: @update[:chat][:id])
    return unless chat

    @message = chat.messages.find_by(telegram_message_id: @update[:message_id])
    return unless @message

    reactions = @count_mode ? reactions_from_counts : reactions_from_user
    @message.update!(reactions: reactions)
  end

  private

  def reactions_from_user
    user = @update[:user]
    return @message.reactions if user.blank?

    db_user = User.find_by(telegram_id: user[:id])
    user_name = db_user&.name || [user[:first_name], user[:last_name]].compact.join(" ").presence || user[:username]

    users = current_users
    key = user[:id].to_s
    emojis = TelegramReaction.emojis(@update[:new_reaction])

    if emojis.empty?
      users.delete(key)
    else
      users[key] = { "name" => user_name, "emojis" => emojis }
    end

    build_reactions(users)
  end

  def reactions_from_counts
    totals = {}

    Array(@update[:reactions]).each do |reaction_count|
      emoji = TelegramReaction.emoji(reaction_count[:type])
      totals[emoji] = reaction_count[:total_count]
    end

    { "users" => current_users, "totals" => totals }
  end

  def current_users
    @message.reactions.fetch("users", {})
  end

  def build_reactions(users)
    totals = Hash.new(0)

    users.each_value do |data|
      Array(data["emojis"]).each { |emoji| totals[emoji] += 1 }
    end

    { "users" => users, "totals" => totals }
  end
end
