class MessageRecorder
  def initialize(chat:, telegram_message:, user: nil, role: :user, content: nil)
    @chat = chat
    @telegram_message = telegram_message
    @user = user
    @role = role
    @content = content
  end

  def record
    @chat.messages.find_or_create_by!(
      telegram_message_id: telegram_message_id
    ) do |message|
      message.role = @role
      message.user = @user
      message.content = message_content
      message.reply_to = reply_to_message
      message.reply_snapshot = reply_snapshot
    end
  end

  private

  def message_content
    @content || @telegram_message[:text] || @telegram_message[:caption]
  end

  def telegram_message_id
    @telegram_message[:message_id]
  end

  def reply_to_message
    parent = @telegram_message[:reply_to_message]
    return unless parent

    @chat.messages.find_by(telegram_message_id: parent[:message_id])
  end

  def reply_snapshot
    parent = @telegram_message[:reply_to_message]
    return if parent.blank? || reply_to_message.present?

    {
      telegram_message_id: parent[:message_id],
      user_name: reply_author_name(parent),
      content: parent[:text] || parent[:caption]
    }.compact
  end

  def reply_author_name(parent)
    from = parent[:from]
    return unless from

    [ from[:first_name], from[:last_name] ].compact.join(" ").presence || from[:username]
  end
end
