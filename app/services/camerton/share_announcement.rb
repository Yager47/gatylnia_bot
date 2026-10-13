module Camerton
  # The bot's reply to a shared link, naming the release so people see the
  # link was understood: "🎵 Queen — Bohemian Rhapsody · пісня". A re-share
  # adds when it was first shared here and its average score.
  class ShareAnnouncement
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
        # Replies to the announcement count as feedback too (ReviewRecorder).
        @share.update!(announced_at: Time.current, announcement_telegram_message_id: reply.telegram_message_id)
      end
    end

    def text
      text =
        if @release.resolved?
          "#{Formatting.release(@release)} · #{Formatting.kind(@release)}"
        else
          "#{Formatting::ICONS.fetch(@release.kind)} #{Formatting.kind(@release).capitalize}: назву на YouTube не знайшов, але відгуки приймаю."
        end

      [ text, history ].compact.join(" · ")
    end

    private

    # Nil for the first share in this chat. The average counts every review
    # here, the sharers' own included.
    def history
      chat_shares = ReleaseShare.where(chat_id: @share.chat_id, release_id: @release.id)
      first_shared_at = chat_shares.where(shared_at: ...@share.shared_at).minimum(:shared_at)
      return unless first_shared_at

      average = Review.where(chat_id: @share.chat_id, release_id: @release.id)
        .where.not(score: nil)
        .average(:score)

      "вже скидали #{first_shared_at.strftime(date_format(first_shared_at))}, " +
        (average ? "середня #{Formatting.score(average)}" : "оцінок ще нема")
    end

    def date_format(time)
      time.year == @share.shared_at.year ? "%d.%m" : "%d.%m.%Y"
    end
  end
end
