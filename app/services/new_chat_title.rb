class NewChatTitle
  def initialize(message)
    @chat = find_chat(message[:chat][:id])
    @new_chat_title = message[:new_chat_title]
  end

  def call
    return unless @chat
    return if @chat.title == @new_chat_title

    @chat.update!(title: @new_chat_title)
  end

  private

  def find_chat(telegram_id)
    Chat.find_by(telegram_id: telegram_id)
  end
end
