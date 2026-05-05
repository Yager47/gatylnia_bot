class MessageHandler
  def initialize(message)
    @message = message
    @chat = set_chat
  end

  def call
    case @chat.mode
    when "default" then DefaultHandler.new(message: @message, chat: @chat).call
    when "accountant" then AccountantHandler.new(message: @message, chat: @chat).call
    end
  end

  private

  def set_chat
    Chat.find_by(telegram_id: @message[:chat][:id]) || create_chat
  end

  def create_chat
    Chat.create!(
      telegram_id:   @message[:chat][:id],
      telegram_type: @message[:chat][:type],
      title:         @message[:chat][:title]
    )
  end
end
