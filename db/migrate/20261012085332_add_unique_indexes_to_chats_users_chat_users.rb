# Built CONCURRENTLY so writes to these tables aren't blocked while the
# indexes build (a plain CREATE INDEX holds a SHARE lock for the whole build).
# CONCURRENTLY can't run inside a transaction, hence disable_ddl_transaction!.
#
# If this fails (e.g. a duplicate row appeared), Postgres leaves the index
# behind as INVALID. Drop it before retrying:
#   remove_index :users, :telegram_id, algorithm: :concurrently, if_exists: true
class AddUniqueIndexesToChatsUsersChatUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :chats, :telegram_id, unique: true, algorithm: :concurrently
    add_index :users, :telegram_id, unique: true, algorithm: :concurrently
    add_index :chat_users, [ :chat_id, :user_id ], unique: true, algorithm: :concurrently
  end
end
