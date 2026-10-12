# For chats that only want features such as Camerton: records messages and
# answers bot commands, but never chats on its own.
class QuietHandler < ChatModeHandler
  private

  def handle
    return if @message[:edit_date].present?
    return unless @message[:text]

    text = record_message.content.downcase
    outcome = Response::BotCommand.new(user: user, text: text, chat: @chat).call
    deliver(outcome) if outcome.is_a?(String)
  end
end
