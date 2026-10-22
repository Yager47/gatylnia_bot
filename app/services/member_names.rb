# What the bot calls members of a chat in its replies: their pseudonym there
# (Response::Pseudonym), else their Telegram name. The chat's pseudonyms load
# in one query on first use, however many names are asked for after.
class MemberNames
  def initialize(chat)
    @chat = chat
  end

  # "Сер Гатило", or "Петро Тест" without a pseudonym.
  def name(user)
    pseudonyms[user.id] || user.name
  end

  # For the canned lines that call people by first name.
  def first_name(user)
    pseudonyms[user.id] || user.first_name
  end

  private

  def pseudonyms
    @pseudonyms ||= @chat.chat_users.where.not(pseudonym: nil).pluck(:user_id, :pseudonym).to_h
  end
end
