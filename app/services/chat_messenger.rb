require "telegram/bot"

class ChatMessenger
  # Telegram allows 4096 characters (UTF-16 units, so an emoji counts as two);
  # longer content goes out as several messages.
  MAX_LENGTH = 4000

  def initialize(chat:, client: TelegramClient.build)
    @chat = chat
    @bot = client
  end

  # reply_to: a Telegram message id to answer in a thread. Still sent if that
  # message was deleted in the meantime.
  # parse_mode: "HTML" when the content is Telegram HTML (links, mentions).
  # Long content is split at blank lines, else at line breaks (HTML tags never
  # span lines here); the message keeps the first part's id, and only that
  # part is threaded.
  def deliver(message, reply_to: nil, parse_mode: nil)
    return if message.content.blank?

    ids = chunks(message.content).each_with_index.map do |text, index|
      send_text(text, reply_to: (reply_to if index.zero?), parse_mode: parse_mode)
    end
    message.update!(telegram_message_id: ids.first) if ids.first
  end

  private

  def send_text(text, reply_to:, parse_mode:)
    params = { chat_id: @chat.telegram_id, text: text }
    params[:parse_mode] = parse_mode if parse_mode
    if reply_to
      params[:reply_parameters] = Telegram::Bot::Types::ReplyParameters.new(message_id: reply_to, allow_sending_without_reply: true)
    end

    extract_message_id(@bot.api.send_message(**params))
  end

  def chunks(text)
    return [ text ] if text.length <= MAX_LENGTH

    pack(text.split("\n\n"), "\n\n") do |paragraph|
      pack(paragraph.split("\n"), "\n") { |line| line.scan(/.{1,#{MAX_LENGTH}}/m) }
    end
  end

  # Joins pieces greedily into chunks of at most MAX_LENGTH. A piece too long
  # on its own is first broken up by the block.
  def pack(pieces, separator, &break_up)
    pieces.flat_map { |piece| piece.length > MAX_LENGTH ? break_up.call(piece) : [ piece ] }
          .each_with_object([]) do |piece, chunks|
            if chunks.any? && chunks.last.length + separator.length + piece.length <= MAX_LENGTH
              chunks.last << separator << piece
            else
              chunks << piece.dup
            end
          end
  end

  def extract_message_id(result)
    return result.message_id if result.respond_to?(:message_id)

    payload = result.is_a?(Hash) ? result : result.to_h
    payload.dig("result", "message_id") || payload["message_id"]
  end
end
