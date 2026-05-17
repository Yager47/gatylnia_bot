class DefaultHandler
  def initialize(message:, chat:)
    @message = message
    @chat = chat
    @user = set_user
    @messenger = ChatMessenger.new(chat: @chat)
  end

  def call
    return unless @message && @message[:date]

    # Skip if message was edited later than minute after the original one.
    # Telegram re-sends video messages as edited message after some time for unknown reason.
    return if @message[:edit_date].present? && (Time.now > Time.at(@message[:date]) + 1.minute)

    if @message[:text]
      message = record_message
      text = message.content.downcase

      Response::Reply.new(user: @user, chat: @chat, text: text, reply_to_message: @message[:reply_to_message]).process
      Response::BotCommand.new(user: @user, text: text, chat: @chat).process
      Response::Gato.new(user: @user, text: text, original_text: @message[:text], chat: @chat).process
      Response::Equals.new(user: @user, text: text).process
      Response::Includes.new(user: @user, text: text).process if chance(0.2)
      Response::Ai.new(chat: @chat).process if chance(0.8)
    else
      Response::VideoNote.new(video_note: @message[:video_note]).process if chance(0.4)
      Response::Voice.new(voice: @message[:voice]).process
      Response::Forward.new(forward_from: @message[:forward_from] || @message[:forward_from_chat]).process
    end

    Response::Chance.new.process if chance(0.2)
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

  def chance(value)
    value > rand
  end
end
