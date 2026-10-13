module Camerton
  # Rebuilds shares and text reviews from a chat's exported history, with the
  # same rules as live messages: a message with a supported link is a share,
  # and a text reply to it is feedback. Silent: no announcements and no
  # reactions; new releases are looked up and each touched review is scored
  # once, in the background.
  #
  # Safe to run again: shares and review messages already stored (by Telegram
  # message id) are kept; a reply whose text changed since is updated.
  # A dry run does everything in a transaction, enqueues no jobs, and rolls
  # it back.
  class HistoryImport
    Report = Data.define(:shares_created, :shares_existing, :releases_created, :replies_created, :replies_updated,
      :reviews_to_score, :skipped)

    # ignored_sender_ids: Telegram ids whose messages are neither shares nor
    # feedback, such as a downloader bot that answers every link with the
    # same link.
    #
    # shares_before: only links shared before this time become shares;
    # replies to them count whenever they were written. Set it to when
    # Camerton went live in the chat: the bot already recorded what came
    # after, and in a basic group the export numbers messages differently
    # from the bot (per account), so those can't be matched by id.
    def initialize(chat:, messages:, dry_run: true, ignored_sender_ids: [], shares_before: nil)
      @chat = chat
      @messages = messages.to_a
      @dry_run = dry_run
      @ignored_sender_ids = ignored_sender_ids.map(&:to_s).to_set
      @shares_before = shares_before
      @skipped = Hash.new(0)
    end

    def call
      report = nil
      # requires_new: a savepoint, so a dry run rolls back even when the
      # caller is already in a transaction (where a plain block would join it
      # and swallow the Rollback).
      ActiveRecord::Base.transaction(requires_new: true) do
        report = import
        raise ActiveRecord::Rollback if @dry_run
      end
      report
    end

    private

    def import
      shares, created_shares, new_releases = import_shares
      reviews, created, updated = import_replies(shares)

      unless @dry_run
        new_releases.each { |release| ResolveReleaseJob.perform_later(release) }
        reviews.each { |review| ScoreReviewJob.perform_later(review, react: false) }
      end

      Report.new(
        shares_created: created_shares, shares_existing: shares.size - created_shares,
        releases_created: new_releases.size, replies_created: created, replies_updated: updated,
        reviews_to_score: reviews.size, skipped: @skipped.dup
      )
    end

    # Returns {telegram message id => share} for every share in the export
    # (and the chat's existing shares, so replies to them count too), the
    # number created, and the releases created.
    # Plain queries rather than @chat's associations: an association caches
    # what it creates, and after a dry run's rollback the cache would still
    # hold the rolled-back shares.
    def import_shares
      shares = ReleaseShare.where(chat: @chat).index_by(&:telegram_message_id)
      created = 0
      new_releases = []

      @messages.each do |message|
        link = Links.first_in(as_telegram_message(message))
        next unless link
        next if shares.key?(message.telegram_message_id)
        next skip(:shares_after_cutoff) if @shares_before && message.sent_at >= @shares_before

        user = sender(message) or next
        release_existed = Release.exists?(platform: link.platform, external_id: link.external_id)
        release = Release.find_or_create_for(link)
        new_releases << release unless release_existed
        shares[message.telegram_message_id] = ReleaseShare.create!(
          chat: @chat, release: release, user: user, telegram_message_id: message.telegram_message_id, shared_at: message.sent_at
        )
        created += 1
      end

      [ shares, created, new_releases ]
    end

    # Text replies to a share (or to the bot's announcement of it) become
    # feedback. Returns the reviews to score and how many replies were
    # created and updated.
    def import_replies(shares)
      by_announcement = shares.values.select(&:announcement_telegram_message_id).index_by(&:announcement_telegram_message_id)
      reviews = Set.new
      created = updated = 0

      @messages.each do |message|
        share = shares[message.reply_to_message_id] || by_announcement[message.reply_to_message_id]
        next unless share && feedback?(message)

        user = sender(message) or next
        review_message = ReviewWriter.new(share: share, user: user).write(
          telegram_message_id: message.telegram_message_id, source: :text, text: message.text, sent_at: message.sent_at,
          score: false
        )
        if review_message.previously_new_record?
          created += 1
        elsif review_message.saved_change_to_text?
          updated += 1
        else
          next
        end
        reviews << review_message.review
      end

      [ reviews, created, updated ]
    end

    # Like Camerton::ReviewRecorder: text that isn't a command to the bot
    # (voice and video notes aren't imported). The bot's own replies are
    # dropped by #sender.
    def feedback?(message)
      return skip(:not_text) if message.text.blank?
      return skip(:bot_commands) if message.text.downcase.start_with?(BotMention.text)
      return skip(:links_in_replies) if Links.first_in(as_telegram_message(message))

      true
    end

    # The chat member who sent it: by the Telegram id from the export, or, for
    # senders without a userpic (no id), by a unique name among the members.
    def sender(message)
      return skip(:bot_messages) if message.sender_id && message.sender_id == bot_id
      return skip(:ignored_senders) if @ignored_sender_ids.include?(message.sender_id)

      if message.sender_id
        ChatMembers::Resolver.new(chat: @chat, from: { id: message.sender_id, first_name: message.sender_name }).call
      else
        matches = members_by_name.fetch(message.sender_name, [])
        matches.one? ? matches.first : skip(:"unknown_sender: #{message.sender_name}")
      end
    end

    def members_by_name
      @members_by_name ||= User.where(id: ChatUser.where(chat: @chat).select(:user_id)).group_by(&:name)
    end

    # The shape Camerton::Links reads: hidden links as text_link entities.
    def as_telegram_message(message)
      {
        text: message.text,
        entities: message.link_urls.map { |url| { type: "text_link", url: url } }
      }.with_indifferent_access
    end

    # The bot's id is the number before the colon in its token.
    def bot_id
      @bot_id ||= ENV.fetch("TELEGRAM_BOT_API_TOKEN").split(":").first
    end

    def skip(reason)
      @skipped[reason] += 1
      nil
    end
  end
end
