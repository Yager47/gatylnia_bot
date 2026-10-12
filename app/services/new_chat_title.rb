class NewChatTitle
  def initialize(message)
    @message = message
  end

  # Active Record skips the UPDATE when the title hasn't changed.
  def call
    Chat.find_by(telegram_id: @message.dig(:chat, :id))&.update!(title: @message[:new_chat_title])
  end
end
