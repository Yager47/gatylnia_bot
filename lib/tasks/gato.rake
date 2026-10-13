namespace :gato do
  # One-off recovery of entries lost with the database, from a Telegram
  # Desktop HTML export. Dry run unless DRY_RUN=0.
  #
  #   bin/rails gato:import_history EXPORT_DIR=tmp/chat_export CHAT_ID=-4915758457 \
  #     FROM="2026-01-01 00:00" TO="2026-04-11 15:29:44"
  desc "Replace a chat's gato entries for FROM...TO (Kyiv time) with ones rebuilt from an HTML chat export"
  task import_history: :environment do
    chat = Chat.find_by!(telegram_id: ENV.fetch("CHAT_ID"))
    from = Time.zone.parse(ENV.fetch("FROM"))
    to = Time.zone.parse(ENV.fetch("TO"))
    dry_run = ENV.fetch("DRY_RUN", "1") != "0"

    report = GatoHistory::Import.new(
      chat: chat,
      messages: TelegramExport::HtmlParser.new(ENV.fetch("EXPORT_DIR")).each_message,
      from: from,
      to: to,
      dry_run: dry_run
    ).call

    puts "#{dry_run ? "DRY RUN, nothing written" : "Done"}: chat #{chat.title.inspect}, #{from} ... #{to}"
    puts "Replaced existing entries: #{report.deleted.inspect}"
    report.created.each { |user, count| puts "  #{user.name} (#{user.telegram_id}): #{count}" }
    puts "Created: #{report.created.values.sum}, removals applied: #{report.removals}"
    puts "Skipped (not a member of this chat / no id in export): #{report.skipped_senders.inspect}" if report.skipped_senders.any?
  end
end
