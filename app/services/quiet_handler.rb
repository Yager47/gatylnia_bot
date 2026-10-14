# For chats that only want features such as Camerton: records messages and
# answers bot commands, but never chats on its own.
class QuietHandler < ChatModeHandler
  private

  def handle
    return if @message[:edit_date].present?
    return unless @message[:text]

    text = record_message.content.downcase
    outcome = Response::BotCommand.new(user: user, text: text, chat: @chat, reply_to_message: @message[:reply_to_message]).call
    deliver(outcome) if Response.answer?(outcome)
  end
end
