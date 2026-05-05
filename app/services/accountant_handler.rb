class AccountantHandler
  def initialize(message:, chat:)
    @bot = Telegram::Bot::Client.new(ENV.fetch("TELEGRAM_BOT_API_TOKEN"))
    @message = message
    @chat = chat
    @user = set_user
  end

  def call
    return unless @message && @message[:date]
    return if @message[:edit_date].present?
    return unless @message[:text]

    message = @chat.messages.create!(
      role: :user,
      user: @user,
      content: @message[:text]
    )
    text = message.content.downcase

    Response::Reply.new(user: @user, chat: @chat, text: text, reply_to_message: @message[:reply_to_message]).process
    Response::BotCommand.new(user: @user, text: text, chat: @chat).process
  rescue Success => e
    message = @chat.messages.create!(role: :assistant, content: e.message)
    send_to_chat message.content
  rescue Skip
    nil
  end

  private

  def set_user
    user = User.find_by(telegram_id: @message[:from][:id]) || create_user
    user.chats << @chat unless user.chats.include?(@chat)
    user
  end

  def create_user
    user = User.new
    user.telegram_id = @message[:from][:id]
    user.username    = @message[:from][:username]
    user.first_name  = @message[:from][:first_name]
    user.last_name   = @message[:from][:last_name]
    user.save!
  end

  def send_to_chat(text)
    return if text.blank?

    @bot.api.send_message(chat_id: @chat.telegram_id, text: text)
  end
end
