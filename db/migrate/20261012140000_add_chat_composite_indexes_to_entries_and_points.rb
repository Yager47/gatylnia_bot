# Composite indexes for the gato stats (entries by chat and time) and the
# balance (points by chat, grouped by user). Each covers lookups by chat_id
# alone, so the single-column chat_id indexes go.
#
# Built CONCURRENTLY so writes aren't blocked while the index builds, which
# can't run inside a transaction. If a concurrent build fails it leaves an
# INVALID index behind: drop it before re-running, since if_not_exists would
# skip it.
class AddChatCompositeIndexesToEntriesAndPoints < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :entries, [ :chat_id, :created_at ], algorithm: :concurrently, if_not_exists: true
    add_index :points, [ :chat_id, :user_id ], algorithm: :concurrently, if_not_exists: true

    remove_index :entries, :chat_id, algorithm: :concurrently, if_exists: true
    remove_index :points, :chat_id, algorithm: :concurrently, if_exists: true
  end
end
