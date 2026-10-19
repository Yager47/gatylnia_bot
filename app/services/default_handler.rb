class DefaultHandler < ChatModeHandler
  LATE_EDIT_AFTER = 1.minute

  private

  def handle
    # Skip if message was edited later than minute after the original one.
    # Telegram re-sends video messages as edited message after some time for unknown reason.
    return if late_edit?

    outcome = Response.first(responders)
    # A random line only when nothing answered or stopped the chain.
    outcome = Response::Chance.new.call if outcome.nil? && chance(0.1)
    deliver(outcome) if Response.answer?(outcome)
  end

  def responders
    if @message[:text]
      text_responders
    elsif @message[:video_note].present?
      [ -> { handle_video_note } ]
    else
      [
        -> { Response::Voice.new(voice: @message[:voice]).call },
        -> { Response::Forward.new(forward_from: @message[:forward_from] || @message[:forward_from_chat]).call }
      ]
    end
  end

  # In priority order: the first one to answer wins. Lambdas, so the dice for
  # the random ones are only rolled when reached.
  def text_responders
    message = record_message
    text = message.content.downcase
    # Telegram delivers an edit as a new update: don't count or undo twice.
    edited = @message[:edit_date].present?

    [
      -> { Response::Reply.new(user: user, chat: @chat, text: text, reply_to_message: @message[:reply_to_message]).call },
      -> { Response::BotCommand.new(user: user, text: text, chat: @chat, reply_to_message: @message[:reply_to_message]).call },
      -> { removal(text) unless edited },
      -> { gato(message, text) unless edited },
      -> { Response::UndoCoffee.new(user: user, text: text, chat: @chat).call unless edited },
      -> { Response::Equals.new(text: text).call },
      -> { track_coffee(message) if !edited && Activities::CoffeeTextClassifier.candidate?(text) },
      -> { Response::Includes.new(user: user, text: text).call if chance(0.1) },
      -> { answer_with_ai(message) }
    ]
  end

  def removal(text)
    Response::Removal.new(user: user, text: text, chat: @chat, reply_to_message: @message[:reply_to_message]).call
  end

  def gato(message, text)
    Response::Gato.new(
      user: user, text: text, original_text: @message[:text], chat: @chat,
      message: message, comment_with_ai: chance(Response::Gato::AI_CHANCE)
    ).call
  end

  # A reply to someone else gets no random line either: not the bot's business.
  def answer_with_ai(message)
    gate = AiReplyGate.new(message)
    return Response::STOP if gate.decision == :never

    Response::Ai.new(chat: @chat, trigger: message).call if gate.decision == :always || chance(AiReplyGate::CHANCE)
  end

  # A possible coffee message gets no other reply here: the job either
  # confirms the coffee or, if it wasn't coffee, replies in character.
  def track_coffee(message)
    TrackCoffeeTextJob.perform_later(message, sent_at: Time.zone.at(@message[:date]))
    Response::STOP
  end

  # The job downloads and analyzes the video, then replies. A video note can't
  # be edited by its author, so an edit is Telegram re-sending it: skip it.
  def handle_video_note
    return Response::STOP if @message[:edit_date].present?

    video_note = @message[:video_note]
    message = record_message(content: Video::NoteAnalyzer.build_description(user, video_note[:duration], nil))
    HandleVideoNoteJob.perform_later(
      message, file_id: video_note[:file_id], duration: video_note[:duration], sent_at: Time.zone.at(@message[:date])
    )
    Response::STOP
  end

  # Both timestamps come from Telegram, so queue lag doesn't matter.
  def late_edit?
    @message[:edit_date].present? && @message[:edit_date] - @message[:date] > LATE_EDIT_AFTER
  end

  def chance(value)
    value > rand
  end
end
