# Replies to the bot's announcement count as feedback too, so the share
# remembers that message's id.
#
# Safe on a populated table: a nullable column without a default is a
# catalog-only change, and the index is built concurrently (outside a
# transaction), so writes to release_shares aren't blocked while it builds.
class AddAnnouncementTelegramMessageIdToReleaseShares < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :release_shares, :announcement_telegram_message_id, :bigint
    add_index :release_shares, [ :chat_id, :announcement_telegram_message_id ],
      unique: true,
      name: "index_release_shares_on_chat_and_announcement",
      where: "announcement_telegram_message_id IS NOT NULL",
      algorithm: :concurrently
  end
end
