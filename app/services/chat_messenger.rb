require "telegram/bot"

class ChatMessenger
  def initialize(chat:, client: TelegramClient.build)
    @chat = chat
    @bot = client
  end

  # reply_to: a Telegram message id to answer in a thread. Still sent if that
  # message was deleted in the meantime.
  def deliver(message, reply_to: nil)
    return if message.content.blank?

    params = { chat_id: @chat.telegram_id, text: message.content }
    if reply_to
      params[:reply_parameters] = Telegram::Bot::Types::ReplyParameters.new(message_id: reply_to, allow_sending_without_reply: true)
    end

    result = @bot.api.send_message(**params)
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
