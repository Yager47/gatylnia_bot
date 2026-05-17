class ChatMessenger
  def initialize(chat:)
    @chat = chat
    @bot = Telegram::Bot::Client.new(ENV.fetch("TELEGRAM_BOT_API_TOKEN"))
  end

  def deliver(message)
    return if message.content.blank?

    result = @bot.api.send_message(chat_id: @chat.telegram_id, text: message.content)
    telegram_message_id = extract_message_id(result)
    message.update!(telegram_message_id: telegram_message_id) if telegram_message_id
  end

  private

  def extract_message_id(result)
    return result.message_id if result.respond_to?(:message_id)

    payload = result.is_a?(Hash) ? result : result.to_h
    payload.dig("result", "message_id") || payload["message_id"]
  end
end
