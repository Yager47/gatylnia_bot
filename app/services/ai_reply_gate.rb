# Whether the AI should answer a recorded user message, judged by whom it's
# addressed to. #decision is one of:
#   :always - it mentions the bot, or replies to the bot's message
#   :never  - it replies to someone else: their conversation, not the bot's
#   :maybe  - addressed to no one in particular; answered with CHANCE
class AiReplyGate
  CHANCE = 0.6

  def initialize(message)
    @message = message
  end

  def decision
    return :always if mentions_bot? || @message.reply_to&.assistant?
    # A reply whose parent isn't recorded (reply_snapshot) still went to
    # someone, most likely a person: the bot's messages are always recorded.
    return :never if @message.reply_to.present? || @message.reply_snapshot.present?

    :maybe
  end

  # roll: a random number in 0...1.
  def answer?(roll)
    case decision
    when :always then true
    when :never then false
    else roll < CHANCE
    end
  end

  private

  def mentions_bot?
    @message.content.to_s.downcase.include?(BotMention.text)
  end
end
