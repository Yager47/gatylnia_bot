# index_chat_users_on_chat_id is covered by the unique (chat_id, user_id)
# index: chat_id is its leading column. Dropped CONCURRENTLY so it doesn't take
# an exclusive lock on chat_users; rollback recreates it the same way.
class RemoveRedundantChatUsersChatIdIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :chat_users, :chat_id, name: "index_chat_users_on_chat_id", algorithm: :concurrently
  end
end
