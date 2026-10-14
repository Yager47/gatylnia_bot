class MessageHandler
  HANDLERS = { "default" => DefaultHandler, "accountant" => AccountantHandler, "quiet" => QuietHandler }.freeze

  def initialize(message)
    @message = message
  end

  # An unknown mode raises KeyError rather than silently ignoring the message.
  # Camerton and notes run first, on top of whatever the mode is.
  def call
    camerton = Camerton::Handler.new(message: @message, chat: chat).call if chat.camerton_enabled?
    # A review belongs to Camerton alone: no canned or AI replies to it, and a
    # video note isn't analyzed (and transcribed) a second time.
    return if camerton == :review
    # Likewise a track or a note on one: saved silently.
    return if chat.notes_enabled? && Notes::Handler.new(message: @message, chat: chat).call

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
