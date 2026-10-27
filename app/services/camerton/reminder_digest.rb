module Camerton
  # The daily nudge in a Camerton chat: each member who hasn't scored a
  # release shared in the last week, or one only in another member's ratings
  # import (RatingsImport) and scored in the last week, with links to those
  # releases, one per line.
  #   🎧 Хто ще не оцінив свіже:
  #
  #   @olya
  #   🎵 Queen — Bohemian Rhapsody
  #   💿 Eminem — Revival
  # The sharer isn't reminded of their own release, and a reply that wasn't
  # a review doesn't count as one. Eight queries however many members and
  # releases there are, pseudonyms included (one fewer with no imports).
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
      blocks = pending_by_member.map do |member, links|
        lines = links.first(PER_MEMBER)
        lines << "і ще #{links.size - PER_MEMBER}" if links.size > PER_MEMBER
        [ Formatting.mention(member, @chat.member_names.name(member)), *lines ].join("\n")
      end
      return if blocks.empty?

      [ "🎧 Хто ще не оцінив свіже:", *blocks, "Відповідайте на реліз текстом, голосовим чи кружечком." ].join("\n\n")
    end

    private

    # [[member, [link to each release they should score]], ...]
    def pending_by_member
      window = (@now - WINDOW)..@now
      latest_shares = @chat.release_shares.where(shared_at: window)
        .includes(:release).order(:shared_at, :id).index_by(&:release_id)
      # release_id => [time, link]: the latest share, or the latest score of
      # a release only imported.
      fresh = latest_shares.transform_values { |share| [ share.shared_at, Formatting.release_link(share, @chat) ] }
      fresh.merge!(imported(window))
      return [] if fresh.empty?

      release_ids = fresh.keys
      sharers = @chat.release_shares.where(release_id: release_ids).distinct.pluck(:release_id, :user_id).to_set
      reviewed = Review.where(chat: @chat, release_id: release_ids).where.not(score: nil).pluck(:release_id, :user_id).to_set
      newest_first = fresh.sort_by { |release_id, (at, _)| [ at, release_id ] }.reverse

      @chat.users.order(:id).filter_map do |member|
        pending = newest_first.filter_map do |release_id, (_, link)|
          link unless sharers.include?([ release_id, member.id ]) || reviewed.include?([ release_id, member.id ])
        end
        [ member, pending ] if pending.any?
      end
    end

    # release_id => [last scored at, link] for releases never shared in the
    # chat that someone scored within the window.
    def imported(window)
      scored_at = Review.where(chat: @chat, scored_at: window).where.not(score: nil)
        .where.not(release_id: @chat.release_shares.select(:release_id)).group(:release_id).maximum(:scored_at)
      releases = Release.where(id: scored_at.keys).index_by(&:id)

      scored_at.to_h { |release_id, at| [ release_id, [ at, Formatting.platform_link(releases.fetch(release_id)) ] ] }
    end
  end
end
