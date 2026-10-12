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
      handle_text
    elsif @message[:video_note].present?
      handle_video_note
    else
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

  def handle_text
    message = record_message
    text = message.content.downcase
    bot_mentioned = text.include?(BOT_MENTION.downcase)
    # Telegram delivers an edit as a new update: don't count or undo twice.
    edited = @message[:edit_date].present?

    Response::Reply.new(user: @user, chat: @chat, text: text, reply_to_message: @message[:reply_to_message]).process
    Response::BotCommand.new(user: @user, text: text, chat: @chat).process
    Response::Gato.new(user: @user, text: text, original_text: @message[:text], chat: @chat).process unless edited
    Response::UndoCoffee.new(user: @user, text: text, chat: @chat).process unless edited
    Response::Equals.new(user: @user, text: text).process
    track_coffee(message) if !edited && Activities::CoffeeTextClassifier.candidate?(text)
    Response::Includes.new(user: @user, text: text).process if chance(0.2)
    Response::Ai.new(chat: @chat).process if bot_mentioned || chance(0.8)
  end

  # A possible coffee message gets no other reply here: the job either
  # confirms the coffee or, if it wasn't coffee, replies in character.
  def track_coffee(message)
    TrackCoffeeTextJob.perform_later(message, sent_at: Time.zone.at(@message[:date]))
    raise Skip
  end

  # The job downloads and analyzes the video, then replies. A video note can't
  # be edited by its author, so an edit is Telegram re-sending it: skip it.
  def handle_video_note
    raise Skip if @message[:edit_date].present?

    video_note = @message[:video_note]
    message = record_message(content: Video::NoteAnalyzer.build_description(@user, video_note[:duration], nil))
    HandleVideoNoteJob.perform_later(
      message, file_id: video_note[:file_id], duration: video_note[:duration], sent_at: Time.zone.at(@message[:date])
    )
    raise Skip
  end

  def record_message(content: nil)
    MessageRecorder.new(
      chat: @chat,
      telegram_message: @message,
      user: @user,
      role: :user,
      content: content
    ).record
  end

  def set_user
    ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
  end

  def chance(value)
    value > rand
  end
end
