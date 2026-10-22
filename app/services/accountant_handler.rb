class AccountantHandler < ChatModeHandler
  private

  def handle
    return if @message[:edit_date].present?
    return unless @message[:text]

    content = record_message.content
    text = content.downcase

    outcome = Response.first([
      -> { Response::Reply.new(user: user, chat: @chat, text: text, reply_to_message: @message[:reply_to_message]).call },
      -> { Response::Pseudonym.new(user: user, chat: @chat, text: content).call },
      -> { Response::BotCommand.new(user: user, text: text, chat: @chat, reply_to_message: @message[:reply_to_message]).call },
      -> { Response::Removal.new(user: user, text: text, chat: @chat, reply_to_message: @message[:reply_to_message]).call }
    ])
    deliver(outcome) if Response.answer?(outcome)
  end
end
