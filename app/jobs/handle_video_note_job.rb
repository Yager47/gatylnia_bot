# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

# Analyzes a video note outside the webhook transaction: a coffee or push-up
# video gets the short confirmation, anything else maybe an in-character AI
# reply (see AiReplyGate).
class HandleVideoNoteJob < ApplicationJob
  queue_as :default

  # Each run downloads the video and runs ffmpeg several times. One at a time
  # keeps memory predictable on the 512MB dyno; video notes are rare enough.
  limits_concurrency to: 1, key: ->(*) { "video_note" }, duration: 5.minutes

  retry_on OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::InternalServerError,
    OpenAI::Errors::RateLimitError,
    Faraday::ConnectionFailed,
    Faraday::TimeoutError,
    wait: :polynomially_longer,
    attempts: 3

  discard_on ActiveJob::DeserializationError

  def perform(message, file_id:, duration:, sent_at:)
    @message = message
    @chat = message.chat
    @user = message.user

    # A retry after the activities were recorded: don't pay for analysis again.
    return if @chat.activities.exists?(telegram_message_id: message.telegram_message_id)

    # Frames live only for this block, removed even if something raises.
    Dir.mktmpdir("video_note") do |dir|
      analysis = Video::NoteAnalyzer.call(video_note: { file_id: file_id, duration: duration }, user: @user, dir: dir)
      @message.update!(content: analysis.description)

      verdict = classify(analysis)
      if verdict&.kinds&.any?
        record_and_confirm(verdict, sent_at)
      else
        reply_in_character(analysis.frame_paths)
      end
    end
  end

  private

  # Nothing to classify when the analysis failed (download error, no ffmpeg
  # and no speech): fall back to the plain AI reply.
  def classify(analysis)
    return if analysis.frame_paths.empty? && analysis.transcript.blank?

    Activities::VideoNoteClassifier.new.call(frame_paths: analysis.frame_paths, transcript: analysis.transcript)
  end

  # Same transaction pattern as TrackCoffeeTextJob: a failed send rolls the
  # records back, so a retry starts clean.
  def record_and_confirm(verdict, sent_at)
    Activity.transaction do
      activities = verdict.kinds.filter_map do |kind|
        Activities::Recorder.new(
          user: @user, chat: @chat, kind: kind, source: :video_note,
          telegram_message_id: @message.telegram_message_id, occurred_at: sent_at,
          details: kind == :coffee ? { "ordinal" => verdict.ordinal }.compact : {}
        ).call
      end
      next if activities.empty?

      recorded = activities.to_h { |activity| [ activity.kind.to_sym, 1 ] }
      reward = activities.sum { |activity| activity.reward&.amount.to_i }
      deliver(Activities::Confirmation.new(user: @user, chat: @chat, day: sent_at).text(recorded, reward: reward))
    end
  end

  def reply_in_character(frame_paths)
    return unless AiReplyGate.new(@message).answer?(rand)

    text = Response::Ai.new(chat: @chat, frames_for: @message, frame_paths: frame_paths).call
    deliver(text, reply_to: (@message.telegram_message_id unless latest?)) if text.is_a?(String)
  end

  # Analysis takes a while: if anything was said since the video, the reply
  # is threaded to it so it's clear what the bot is answering.
  def latest?
    !@chat.messages.exists?([ "telegram_message_id > ?", @message.telegram_message_id ])
  end

  def deliver(text, reply_to: nil)
    reply = @chat.messages.create!(role: :assistant, content: text)
    ChatMessenger.new(chat: @chat).deliver(reply, reply_to: reply_to)
  end
end
