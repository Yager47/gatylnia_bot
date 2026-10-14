require "erb"

module Camerton
  # "@bot що послухати" / "@bot що послухати @нік": the 10 most recently
  # shared releases a member hasn't scored yet, however old. Like the daily
  # digest, the member's own shares are left out and a reply that wasn't a
  # review doesn't count. Each release links to its latest share, as in the
  # digest, so the text is Telegram HTML. Three queries however many
  # releases the chat has.
  class ToListen
    SHOWN = 10

    def initialize(chat:, user:)
      @chat = chat
      @user = user
    end

    # Telegram HTML.
    def text
      name = ERB::Util.html_escape(@user.name)
      shares = latest_shares.includes(:release).order(shared_at: :desc, id: :desc).limit(SHOWN).to_a
      return "🎧 #{name}: усе вже оцінено." if shares.empty?

      lines = shares.map { |share| Formatting.release_link(share, @chat) }
      total = pending.distinct.count(:release_id)
      lines << "і ще #{total - SHOWN}" if total > SHOWN

      [ "🎧 Що ще послухати — #{name}:", "", *lines ].join("\n")
    end

    private

    # The chat's shares of releases the member neither shared nor scored.
    def pending
      own = @chat.release_shares.where(user: @user).select(:release_id)
      scored = Review.where(chat: @chat, user: @user).where.not(score: nil).select(:release_id)

      @chat.release_shares.where.not(release_id: own).where.not(release_id: scored)
    end

    # The latest share of each pending release: a re-share brings it back up.
    def latest_shares
      newest_per_release = pending.select("DISTINCT ON (release_shares.release_id) release_shares.*")
        .order(:release_id, shared_at: :desc, id: :desc)

      ReleaseShare.from(newest_per_release, :release_shares)
    end
  end
end
