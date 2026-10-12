module Camerton
  # A reply to a share (or to the bot's announcement of it) is feedback.
  # Text is stored as written right away; a voice or video note is
  # transcribed in the background first (TranscribeReviewJob).
  class ReviewRecorder
    MEDIA_SOURCES = %i[voice video_note].freeze

    def initialize(message:, chat:)
      @message = message
      @chat = chat
    end

    # Returns the feedback's source (:text, :voice or :video_note), or nil
    # when the message isn't feedback.
    def call
      share = replied_share
      return unless share

      if media_source
        enqueue_transcription(share)
      elsif text.present?
        ReviewWriter.new(share: share, user: user)
          .write(telegram_message_id: @message[:message_id], source: :text, text: text, sent_at: sent_at)
        :text
      end
    end

    private

    # The link message itself or the bot's announcement under it.
    def replied_share
      replied_id = @message.dig(:reply_to_message, :message_id)
      return unless replied_id

      @chat.release_shares
        .where(telegram_message_id: replied_id)
        .or(@chat.release_shares.where(announcement_telegram_message_id: replied_id))
        .first
    end

    def media_source
      MEDIA_SOURCES.find { |source| @message[source].present? }
    end

    # Voice and video notes can't be edited by their author; an edited one is
    # Telegram re-sending it, so it isn't transcribed again (but is still
    # feedback, which keeps the mode handler off it).
    def enqueue_transcription(share)
      unless @message[:edit_date].present?
        TranscribeReviewJob.perform_later(
          share, user,
          telegram_message_id: @message[:message_id],
          file_id: @message[media_source][:file_id],
          source: media_source.to_s,
          caption: @message[:caption],
          sent_at: sent_at
        )
      end

      media_source
    end

    def text
      @message[:text] || @message[:caption]
    end

    def sent_at
      Time.zone.at(@message[:date])
    end

    def user
      @user ||= ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
    end
  end
end
