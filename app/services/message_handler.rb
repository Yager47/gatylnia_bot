class MessageHandler
  def initialize(message)
    @bot = Telegram::Bot::Client.new(ENV.fetch("TELEGRAM_BOT_API_TOKEN"))
    @message = message
    @chat = process_chat
    @user = process_user

    @text = nil
  end

  def call
    return unless @message && @message[:date]

    # Skip if message was edited later than minute after the original one.
    # Telegram re-sends video messages as edited message after some time for unknown reason.
    return if @message[:edit_date].present? && (Time.now > Time.at(@message[:date]) + 1.minute)

    if @message[:text]
      @text = @message[:text].downcase

      Response::BotCommand.new(user: @user, text: @text, chat: @chat).process
      Response::Gato.new(user: @user, text: @text, original_text: @message[:text], chat: @chat).process
      Response::Equals.new(user: @user, text: @text).process
      Response::Includes.new(user: @user, text: @text).process
    else
      Response::VideoNote.new(video_note: @message[:video_note]).process
      Response::Voice.new(voice: @message[:voice]).process
      Response::Forward.new(forward_from: @message[:forward_from] || @message[:forward_from_chat]).process
    end

    Response::Chance.new.process
  rescue Success => e
    send_to_chat e.message
  end

  private

  def process_chat
    Chat.find_by(telegram_id: @message[:chat][:id]) ||
      begin
        Chat.create!(
          telegram_id: @message[:chat][:id],
          telegram_type: @message[:chat][:type],
          title: @message[:chat][:title]
        )
      end
  end

  def process_user
    user = User.find_by(telegram_id: @message[:from][:id]) || create_user
    user.chats << @chat unless user.chats.include?(@chat)
    user
  end

  def create_user
    user = User.new
    user.telegram_id = @message[:from][:id]
    user.username = @message[:from][:username]
    user.first_name = @message[:from][:first_name]
    user.last_name = @message[:from][:last_name]
    user.save!
  end

  def send_to_chat(text)
    return if text.blank?

    @bot.api.send_message(chat_id: @chat.telegram_id, text: text)
  end
end
