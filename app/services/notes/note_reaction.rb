require "telegram/bot"

module Notes
  # The bot's ✍ on a note's message, so its author sees it was saved
  # (Telegram allows no check mark among reactions). Cosmetic: a failure is
  # logged, never raised, so it can't undo the note or cost a retry.
  class NoteReaction
    EMOJI = "✍".freeze

    def initialize(note, client: TelegramClient.build)
      @note = note
      @client = client
    end

    def call
      @client.api.set_message_reaction(
        chat_id: @note.audio_track.chat.telegram_id,
        message_id: @note.telegram_message_id,
        reaction: [ Telegram::Bot::Types::ReactionTypeEmoji.new(type: "emoji", emoji: EMOJI) ]
      )
    rescue Telegram::Bot::Exceptions::ResponseError, Faraday::Error => e
      Rails.logger.warn("[Notes::NoteReaction] TrackNote #{@note.id}: #{e.class}: #{e.message}")
    end
  end
end
