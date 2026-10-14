# Plumbing shared by the per-mode message handlers (see MessageHandler).
# Building one does no database work; subclasses implement #handle.
class ChatModeHandler
  def initialize(message:, chat:)
    @message = message
    @chat = chat
  end

  def call
    user # every message makes its sender a chat member, answered or not
    handle
  end

  private

  def handle
    raise NotImplementedError
  end

  # Finds or creates the sender and their membership in the chat.
  def user
    @user ||= ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
  end

  def record_message(content: nil)
    MessageRecorder.new(chat: @chat, telegram_message: @message, user: user, role: :user, content: content).record
  end

  # outcome: a String, or a Response::Threaded to answer a given message.
  def deliver(outcome)
    text, reply_to = outcome.is_a?(Response::Threaded) ? [ outcome.text, outcome.reply_to ] : [ outcome, nil ]
    reply = @chat.messages.create!(role: :assistant, content: text)
    ChatMessenger.new(chat: @chat).deliver(reply, reply_to: reply_to)
  end
end
