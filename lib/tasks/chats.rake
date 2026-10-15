namespace :chats do
  # Negates the message numbers a chat stored before it became a supergroup
  # (see PreSupergroupMessageIds). New migrations do it themselves; this is
  # for chats migrated before that, or to catch rows written late. Dry run
  # (shows each side of supergroup_since) unless DRY_RUN=0.
  #
  #   bin/rails chats:negate_pre_supergroup_ids CHAT_ID=-1004499357183
  desc "Negate a supergroup's message numbers from when it was a basic group"
  task negate_pre_supergroup_ids: :environment do
    chat = Chat.find_by!(telegram_id: ENV.fetch("CHAT_ID"))
    abort "Chat #{chat.title.inspect} has no supergroup_since" unless chat.supergroup_since

    dry_run = ENV.fetch("DRY_RUN", "1") != "0"
    renumbering = PreSupergroupMessageIds.new(chat)

    puts "Chat #{chat.title.inspect}, supergroup since #{chat.supergroup_since}"
    renumbering.stats.each do |stats|
      puts "#{stats.label}: #{stats.old_count} old #{stats.old_range.inspect}, #{stats.new_count} new #{stats.new_range.inspect}"
    end

    if dry_run
      puts "DRY RUN, nothing written"
    else
      puts "Done: #{renumbering.call.inspect}"
    end
  end
end
