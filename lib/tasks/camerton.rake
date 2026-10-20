namespace :camerton do
  # Imports shares and text reviews from a Telegram Desktop HTML export of a
  # Camerton chat. Silent; dry run unless DRY_RUN=0. IGNORE_SENDER_IDS skips
  # senders (comma-separated Telegram ids), e.g. a downloader bot.
  # SHARES_BEFORE (Kyiv time) imports only links shared before Camerton went
  # live in the chat; the bot recorded the later ones itself.
  #
  #   bin/rails camerton:import_history EXPORT_DIR=tmp/music_export CHAT_ID=-4828587211 \
  #     IGNORE_SENDER_IDS=1793352182 SHARES_BEFORE="2026-10-13 12:24:37"
  desc "Import Camerton shares and text reviews from an HTML chat export"
  task import_history: :environment do
    chat = Chat.find_by!(telegram_id: ENV.fetch("CHAT_ID"))
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    shares_before = Time.zone.parse(ENV["SHARES_BEFORE"]) if ENV["SHARES_BEFORE"].present?

    report = Camerton::HistoryImport.new(
      chat: chat,
      messages: TelegramExport::HtmlParser.new(ENV.fetch("EXPORT_DIR")).each_message,
      dry_run: dry_run,
      ignored_sender_ids: ENV.fetch("IGNORE_SENDER_IDS", "").split(",").map(&:strip).reject(&:empty?),
      shares_before: shares_before
    ).call

    puts "#{dry_run ? 'DRY RUN, nothing written' : 'Done'}: chat #{chat.title.inspect}#{' (Camerton is off)' unless chat.camerton_enabled?}"
    puts "Shares only before #{shares_before}" if shares_before
    puts "Shares: #{report.shares_created} new, #{report.shares_existing} already there (new releases to look up: #{report.releases_created})"
    puts "Replies: #{report.replies_created} new, #{report.replies_updated} updated; reviews to score: #{report.reviews_to_score}"
    puts "Skipped: #{report.skipped.inspect}" if report.skipped.any?
  end

  # Imports a member's scores from their ratings spreadsheet, exported as a
  # JSON array of {"url", "artist", "title", "year", "score"}. Silent; dry
  # run unless DRY_RUN=0. CHAT_ID and USER_ID are Telegram ids.
  #
  #   bin/rails camerton:import_ratings RATINGS_FILE=tmp/ratings.json CHAT_ID=-1004499357183 USER_ID=123
  desc "Import a member's Camerton scores from a ratings spreadsheet (as JSON)"
  task import_ratings: :environment do
    chat = Chat.find_by!(telegram_id: ENV.fetch("CHAT_ID"))
    user = chat.users.find_by!(telegram_id: ENV.fetch("USER_ID"))
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    ratings = JSON.parse(File.read(ENV.fetch("RATINGS_FILE"))).map do |row|
      Camerton::RatingsImport::Rating.new(**row.slice("url", "artist", "title", "year", "score").symbolize_keys)
    end

    report = Camerton::RatingsImport.new(chat: chat, user: user, ratings: ratings, dry_run: dry_run).call

    puts "#{dry_run ? 'DRY RUN, nothing written' : 'Done'}: #{ratings.size} ratings by #{user.name} in #{chat.title.inspect}"
    puts "Releases: #{report.releases_created} new, #{report.releases_merged} merged into one the chat has"
    puts "Reviews: #{report.reviews_created} new, #{report.reviews_filled} filled in"
    report.skipped.each { |reason, names| puts "Skipped #{reason} (#{names.size}): #{names.join('; ')}" }
  end

  # Adds Discogs genres, styles, year and album to releases never checked
  # (imported ones). Paced to the rate limit: about 5 seconds a release, 2
  # with DISCOGS_TOKEN. Safe to stop and run again. Dry run unless DRY_RUN=0.
  #
  #   bin/rails camerton:discogs_backfill DRY_RUN=0
  desc "Look up Discogs genres and styles for releases never checked"
  task discogs_backfill: :environment do
    # A detached dyno's stdout is a pipe, which Ruby buffers: without this the
    # per-release lines reach `heroku logs` only in chunks or at the end.
    $stdout.sync = true
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    backfill = Camerton::DiscogsBackfill.new
    count = Camerton::DiscogsBackfill.releases.count

    if dry_run
      puts "DRY RUN, nothing asked: #{count} releases to look up, about #{(count * backfill.pause / 60).ceil} minutes"
      next
    end

    report = backfill.call
    puts "Done: #{report.matched} matched, #{report.unmatched} no match, #{report.failed} failed (run again for those)"
  end

  # Merges releases resolved before ReleaseMerge existed: each one with the
  # same kind, artist and title as an older release. Newest first, so all of
  # a name's duplicates merge into its oldest release. Dry run unless DRY_RUN=0.
  #
  #   bin/rails camerton:merge_duplicate_releases DRY_RUN=0
  desc "Merge Camerton releases that are the same song or album"
  task merge_duplicate_releases: :environment do
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    merged = 0

    Release.resolved.where(merged_into_id: nil).find_each(order: :desc) do |release|
      merge = Camerton::ReleaseMerge.new(release)
      # Only into an older release: the oldest one of a name stays (in a dry
      # run nothing is marked merged, so it would see a newer one as target).
      target = merge.target
      next unless target && target.id < release.id

      moving = "#{release.shares.count} shares, #{release.reviews.count} reviews"
      merge.call unless dry_run
      merged += 1
      puts "#{release.id} → #{target.id}: #{Camerton::Formatting.release(target)} (#{moving})"
    end

    puts "#{dry_run ? 'DRY RUN, nothing written' : 'Done'}: #{merged} releases #{dry_run ? "to merge" : "merged"}"
  end
end
