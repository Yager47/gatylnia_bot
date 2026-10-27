require "erb"

module Camerton
  # "@bot що послухати [альбоми|пісні] [жанр] [@нік]": the 10 latest releases
  # a member hasn't scored yet, however old, optionally only albums or songs
  # and only a Discogs genre or style (Release.with_genre). A release is
  # either shared in the chat, by its latest share, or only in another
  # member's ratings import (RatingsImport), by when it was last scored.
  # Like the daily digest, the member's own shares are left out and a reply
  # that wasn't a review doesn't count. Each release links to its latest
  # share (or YouTube Music when that has no link, or it was never shared),
  # as in the digest, so the text is Telegram HTML. Seven queries however
  # many releases the chat has (one for pseudonyms; one fewer with no
  # imports), plus one when a genre finds nothing.
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
      name = ERB::Util.html_escape(@chat.member_names.name(@user))
      shares = latest_shares.includes(:release).order(shared_at: :desc, id: :desc).limit(SHOWN).to_a
      entries = shares.map { |share| [ share.shared_at, Formatting.release_link(share, @chat) ] } + latest_imported
      return nothing_left(name) if entries.empty?

      # Newest first; sort_by isn't stable, so the index keeps each list's order on a tie.
      lines = entries.each_with_index.sort_by { |(at, _), index| [ -at.to_f, index ] }.first(SHOWN).map { |(_, line), _| line }
      total = pending.distinct.count(:release_id) + imported.distinct.count(:release_id)
      lines << "і ще #{total - SHOWN}" if total > SHOWN

      [ "🎧 Що ще послухати — #{name}#{filter_label}:", "", *lines ].join("\n")
    end

    private

    # A genre nobody shared or imported reads better as that than as "all scored".
    def nothing_left(name)
      if @genre && !in_chat?(matching_releases)
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

    def in_chat?(releases)
      ids = releases.select(:id)
      @chat.release_shares.exists?(release_id: ids) || Review.where(chat: @chat, release_id: ids).exists?
    end

    def scored
      Review.where(chat: @chat, user: @user).where.not(score: nil).select(:release_id)
    end

    # The chat's shares of releases the member neither shared nor scored,
    # within the filters.
    def pending
      own = @chat.release_shares.where(user: @user).select(:release_id)

      shares = @chat.release_shares.where.not(release_id: own).where.not(release_id: scored)
      shares = shares.where(release_id: matching_releases.select(:id)) if @kind || @genre
      shares
    end

    # Other members' scores of releases never shared in the chat (their
    # ratings imports) that the member hasn't scored, within the filters.
    # The member's own imports are scored, so they're left out too.
    def imported
      reviews = Review.where(chat: @chat).where.not(user: @user).where.not(score: nil)
        .where.not(release_id: @chat.release_shares.select(:release_id)).where.not(release_id: scored)
      reviews = reviews.where(release_id: matching_releases.select(:id)) if @kind || @genre
      reviews
    end

    # [[last scored at, link], ...] for the 10 latest imported releases.
    def latest_imported
      scored_at = imported.group(:release_id).order(Arel.sql("MAX(reviews.scored_at) DESC NULLS LAST"), :release_id).limit(SHOWN).maximum(:scored_at)
      releases = Release.where(id: scored_at.keys).index_by(&:id)

      scored_at.map { |release_id, at| [ at, Formatting.platform_link(releases.fetch(release_id)) ] }
    end

    # The latest share of each pending release: a re-share brings it back up.
    def latest_shares
      newest_per_release = pending.select("DISTINCT ON (release_shares.release_id) release_shares.*")
        .order(:release_id, shared_at: :desc, id: :desc)

      ReleaseShare.from(newest_per_release, :release_shares)
    end
  end
end
