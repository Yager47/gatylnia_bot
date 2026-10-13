namespace :camerton do
  # Imports shares and text reviews from a Telegram Desktop HTML export of a
  # Camerton chat. Silent; dry run unless DRY_RUN=0.
  #
  #   bin/rails camerton:import_history EXPORT_DIR=tmp/music_export CHAT_ID=-1001234567890
  desc "Import Camerton shares and text reviews from an HTML chat export"
  task import_history: :environment do
    chat = Chat.find_by!(telegram_id: ENV.fetch("CHAT_ID"))
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"

    report = Camerton::HistoryImport.new(
      chat: chat,
      messages: TelegramExport::HtmlParser.new(ENV.fetch("EXPORT_DIR")).each_message,
      dry_run: dry_run
    ).call

    puts "#{dry_run ? 'DRY RUN, nothing written' : 'Done'}: chat #{chat.title.inspect}#{' (Camerton is off)' unless chat.camerton_enabled?}"
    puts "Shares: #{report.shares_created} new, #{report.shares_existing} already there (new releases to look up: #{report.releases_created})"
    puts "Replies: #{report.replies_created} new, #{report.replies_updated} updated; reviews to score: #{report.reviews_to_score}"
    puts "Skipped: #{report.skipped.inspect}" if report.skipped.any?
  end
end
