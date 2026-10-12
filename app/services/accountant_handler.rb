class AccountantHandler
  def initialize(message:, chat:)
    @message = message
    @chat = chat
    @user = set_user
    @messenger = ChatMessenger.new(chat: @chat)
  end

  def call
    return unless @message && @message[:date]
    return if @message[:edit_date].present?
    return unless @message[:text]

    message = record_message
    text = message.content.downcase

    Response::Reply.new(user: @user, chat: @chat, text: text, reply_to_message: @message[:reply_to_message]).process
    Response::BotCommand.new(user: @user, text: text, chat: @chat).process
  rescue Success => e
    reply = @chat.messages.create!(role: :assistant, content: e.message)
    @messenger.deliver(reply)
  rescue Skip
    nil
  end

  private

  def record_message
    MessageRecorder.new(
      chat: @chat,
      telegram_message: @message,
      user: @user,
      role: :user
    ).record
  end

  def set_user
    ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
  end
end
