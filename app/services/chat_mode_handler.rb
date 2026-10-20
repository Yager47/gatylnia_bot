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

  # outcome: a String, a Response::Threaded to answer a given message, or a
  # Response::Html. HTML replies are lists ("що послухати", help), so a
  # preview of their first link would only get in the way.
  def deliver(outcome)
    text, reply_to, parse_mode =
      case outcome
      when Response::Threaded then [ outcome.text, outcome.reply_to, nil ]
      when Response::Html then [ outcome.text, nil, "HTML" ]
      else [ outcome, nil, nil ]
      end
    reply = @chat.messages.create!(role: :assistant, content: text)
    ChatMessenger.new(chat: @chat).deliver(reply, reply_to: reply_to, parse_mode: parse_mode, link_preview: parse_mode.nil?)
  end
end
