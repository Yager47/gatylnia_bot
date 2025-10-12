class NewChatTitle
  def initialize(message)
    @chat = Chat.find_by(telegram_id: message[:chat][:id])
    @new_chat_title = message[:new_chat_title]
  end

  def call
    return unless @chat

    @chat.title = @new_chat_title
    @chat.save!
  end
end
