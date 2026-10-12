class MessageHandler
  HANDLERS = { "default" => DefaultHandler, "accountant" => AccountantHandler }.freeze

  def initialize(message)
    @message = message
  end

  # An unknown mode raises KeyError rather than silently ignoring the message.
  def call
    HANDLERS.fetch(chat.mode).new(message: @message, chat: chat).call
  end

  private

  def chat
    @chat ||= find_or_create_chat
  end

  # find_by first for the common case; create_or_find_by! makes creating a
  # new chat safe when two updates from it are processed at once.
  def find_or_create_chat
    Chat.find_by(telegram_id: @message[:chat][:id]) ||
      Chat.create_or_find_by!(telegram_id: @message[:chat][:id]) do |chat|
        chat.telegram_type = @message[:chat][:type]
        chat.title = @message[:chat][:title]
      end
  end
end
