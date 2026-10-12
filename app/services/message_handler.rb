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

  # find_by first for the common case; create_or_find_by! makes creating a
  # new chat safe when two updates from it are processed at once.
  def set_chat
    Chat.find_by(telegram_id: @message[:chat][:id]) ||
      Chat.create_or_find_by!(telegram_id: @message[:chat][:id]) do |chat|
        chat.telegram_type = @message[:chat][:type]
        chat.title = @message[:chat][:title]
      end
  end
end
