module Camerton
  # The bot's reply to a shared link, naming the release so people see the
  # link was understood: "🎵 Queen — Bohemian Rhapsody · пісня".
  class ShareAnnouncement
    ICONS = { "song" => "🎵", "album" => "💿" }.freeze
    KINDS = { "song" => "пісня", "album" => "альбом" }.freeze

    def initialize(share)
      @share = share
      @release = share.release
    end

    # Sends once per share, and only once the release has been looked up.
    # The row lock makes a parallel job wait and then see announced_at; if the
    # send fails, the lock's transaction rolls back the assistant message.
    def deliver
      return if @release.pending?

      @share.with_lock do
        next if @share.announced_at

        chat = @share.chat
        reply = chat.messages.create!(role: :assistant, content: text)
        ChatMessenger.new(chat: chat).deliver(reply, reply_to: @share.telegram_message_id)
        @share.update!(announced_at: Time.current)
      end
    end

    def text
      icon = ICONS.fetch(@release.kind)
      kind = KINDS.fetch(@release.kind)

      if @release.resolved?
        "#{icon} #{[ @release.artist, @release.title ].compact.join(' — ')} · #{kind}"
      else
        "#{icon} #{kind.capitalize}: назву на YouTube не знайшов, але відгуки приймаю."
      end
    end
  end
end
