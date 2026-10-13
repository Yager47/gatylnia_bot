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
end
