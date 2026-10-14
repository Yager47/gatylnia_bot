# Loads Faraday, whose errors are retried below (the file lookup goes through it).
require "telegram/bot"

# Turns a voice or video note reply to a track into a note. Whisper takes the
# video note's mp4 as is and only uses its audio.
class TranscribeNoteJob < ApplicationJob
  queue_as :default

  # One at a time: keeps memory predictable on the 512MB dyno, and a
  # redelivered reply's job waits and then finds the note already stored.
  limits_concurrency to: 1, key: ->(*, **) { "note_transcription" }, duration: 5.minutes

  retry_on OpenAI::Errors::APIConnectionError,
    OpenAI::Errors::InternalServerError,
    OpenAI::Errors::RateLimitError,
    Faraday::ConnectionFailed,
    Faraday::TimeoutError,
    Net::OpenTimeout,
    Net::ReadTimeout,
    TelegramFileDownloader::Error,
    wait: :polynomially_longer,
    attempts: 3

  discard_on ActiveJob::DeserializationError

  def perform(track, user, telegram_message_id:, file_id:, source:, caption:, sent_at:)
    # A retry or redelivery after it was stored: don't pay for Whisper again.
    return if track.notes.exists?(telegram_message_id: telegram_message_id)

    transcript = Dir.mktmpdir("note_audio") do |dir|
      Video::NoteTranscriber.call(TelegramFileDownloader.download(file_id, dir: dir))
    end
    text = [ caption.presence, transcript.strip.presence ].compact.join("\n")
    # Nothing was said (music, silence): no note.
    return if text.empty?

    Notes::NoteWriter.new(track: track, user: user)
      .write(telegram_message_id: telegram_message_id, source: source, text: text, sent_at: sent_at)
  end
end
