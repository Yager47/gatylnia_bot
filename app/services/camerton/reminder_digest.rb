module Camerton
  # The daily nudge in a Camerton chat: each member who hasn't scored a
  # release shared in the last week, with links to those releases, one per
  # line.
  #   🎧 Хто ще не оцінив свіже:
  #
  #   @olya
  #   🎵 Queen — Bohemian Rhapsody
  #   💿 Eminem — Revival
  # The sharer isn't reminded of their own release, and a reply that wasn't
  # a review doesn't count as one. Five queries however many members and
  # releases there are, pseudonyms included.
  class ReminderDigest
    WINDOW = 7.days
    PER_MEMBER = 5

    def initialize(chat, now: Time.current)
      @chat = chat
      @now = now
    end

    # Sends at most once per Kyiv day. The chat row lock makes a parallel or
    # repeated run wait and then see the date; if sending fails, the date
    # and the assistant message roll back so a retry starts clean.
    def deliver
      today = @now.to_date

      @chat.with_lock do
        next unless @chat.camerton_enabled?
        next if @chat.camerton_digest_sent_on == today

        if (body = text)
          reply = @chat.messages.create!(role: :assistant, content: body)
          ChatMessenger.new(chat: @chat).deliver(reply, parse_mode: "HTML", link_preview: false)
        end
        @chat.update!(camerton_digest_sent_on: today)
      end
    end

    # HTML for Telegram, or nil when nobody has anything to score.
    def text
      blocks = pending_by_member.map do |member, shares|
        lines = shares.first(PER_MEMBER).map { |share| Formatting.release_link(share, @chat) }
        lines << "і ще #{shares.size - PER_MEMBER}" if shares.size > PER_MEMBER
        [ Formatting.mention(member, @chat.member_names.name(member)), *lines ].join("\n")
      end
      return if blocks.empty?

      [ "🎧 Хто ще не оцінив свіже:", *blocks, "Відповідайте на реліз текстом, голосовим чи кружечком." ].join("\n\n")
    end

    private

    # [[member, [latest share of each release they should score]], ...]
    def pending_by_member
      latest_shares = @chat.release_shares.where(shared_at: (@now - WINDOW)..@now)
        .includes(:release).order(:shared_at, :id).index_by(&:release_id)
      return [] if latest_shares.empty?

      release_ids = latest_shares.keys
      sharers = @chat.release_shares.where(release_id: release_ids).distinct.pluck(:release_id, :user_id).to_set
      reviewed = Review.where(chat: @chat, release_id: release_ids).where.not(score: nil).pluck(:release_id, :user_id).to_set
      newest_first = latest_shares.values.reverse

      @chat.users.order(:id).filter_map do |member|
        pending = newest_first.reject do |share|
          sharers.include?([ share.release_id, member.id ]) || reviewed.include?([ share.release_id, member.id ])
        end
        [ member, pending ] if pending.any?
      end
    end
  end
end
