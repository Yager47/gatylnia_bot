# A basic group upgraded to a supergroup gets a new Telegram id. Points the
# chat's row at the new id, so everything stored for the chat stays with it.
#
# Telegram announces it twice, in the old chat (migrate_to_chat_id) and in
# the new one (migrate_from_chat_id), in either order and possibly in
# parallel; the row lock and the lookup by the old id make the second call a
# no-op.
#
# If the new id already has its own row (the service messages were missed
# and a later message created it), both rows are left alone and an error is
# logged: merging them needs a look at what each holds.
class ChatMigration
  def initialize(from:, to:)
    @from = from.to_s
    @to = to.to_s
  end

  # Returns the migrated chat, or nil if there was nothing to migrate.
  def call
    Chat.transaction do
      chat = Chat.lock.find_by(telegram_id: @from)
      next unless chat

      if Chat.exists?(telegram_id: @to)
        Rails.logger.error("[ChatMigration] chat #{chat.id}: #{@to} already has its own row, not migrating from #{@from}")
        next
      end

      chat.update!(telegram_id: @to, telegram_type: "supergroup")
      chat
    end
  end
end
