require "erb"

module Camerton
  # "@bot що послухати [альбоми|пісні] [жанр] [@нік]": the 10 most recently
  # shared releases a member hasn't scored yet, however old, optionally only
  # albums or songs and only a Discogs genre or style (Release.with_genre).
  # Like the daily digest, the member's own shares are left out and a reply
  # that wasn't a review doesn't count. Each release links to its latest
  # share, as in the digest, so the text is Telegram HTML. Three queries
  # however many releases the chat has, plus one when a genre finds nothing.
  class ToListen
    SHOWN = 10
    KIND_LABELS = { "album" => "альбоми", "song" => "пісні" }.freeze
    # "Не знайшов … з жанром": genitive plural.
    KIND_NOT_FOUND = { "album" => "альбомів", "song" => "пісень" }.freeze

    # kind: "album" or "song"; genre: any text, matched as a substring.
    def initialize(chat:, user:, kind: nil, genre: nil)
      @chat = chat
      @user = user
      @kind = kind
      @genre = genre
    end

    # Telegram HTML.
    def text
      name = ERB::Util.html_escape(@user.name)
      shares = latest_shares.includes(:release).order(shared_at: :desc, id: :desc).limit(SHOWN).to_a
      return nothing_left(name) if shares.empty?

      lines = shares.map { |share| Formatting.release_link(share, @chat) }
      total = pending.distinct.count(:release_id)
      lines << "і ще #{total - SHOWN}" if total > SHOWN

      [ "🎧 Що ще послухати — #{name}#{filter_label}:", "", *lines ].join("\n")
    end

    private

    # A genre nobody shared reads better as that than as "all scored".
    def nothing_left(name)
      if @genre && !@chat.release_shares.exists?(release_id: matching_releases.select(:id))
        "🎧 Не знайшов у чаті #{KIND_NOT_FOUND.fetch(@kind, 'релізів')} з жанром «#{ERB::Util.html_escape(@genre)}»."
      else
        "🎧 #{name}#{filter_label}: усе вже оцінено."
      end
    end

    # " (альбоми, rock)", or nothing without filters.
    def filter_label
      parts = [ KIND_LABELS[@kind], @genre && ERB::Util.html_escape(@genre) ].compact
      parts.any? ? " (#{parts.join(', ')})" : ""
    end

    def matching_releases
      releases = Release.all
      releases = releases.where(kind: @kind) if @kind
      releases = releases.with_genre(@genre) if @genre
      releases
    end

    # The chat's shares of releases the member neither shared nor scored,
    # within the filters.
    def pending
      own = @chat.release_shares.where(user: @user).select(:release_id)
      scored = Review.where(chat: @chat, user: @user).where.not(score: nil).select(:release_id)

      shares = @chat.release_shares.where.not(release_id: own).where.not(release_id: scored)
      shares = shares.where(release_id: matching_releases.select(:id)) if @kind || @genre
      shares
    end

    # The latest share of each pending release: a re-share brings it back up.
    def latest_shares
      newest_per_release = pending.select("DISTINCT ON (release_shares.release_id) release_shares.*")
        .order(:release_id, shared_at: :desc, id: :desc)

      ReleaseShare.from(newest_per_release, :release_shares)
    end
  end
end
