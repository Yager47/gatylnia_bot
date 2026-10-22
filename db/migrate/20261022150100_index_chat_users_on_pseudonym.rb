# No two members of a chat with the same pseudonym, whatever the case. Built
# CONCURRENTLY so writes aren't blocked; that can't run inside a transaction.
# If the build fails it leaves an INVALID index behind: drop it before
# re-running, since if_not_exists would skip it.
class IndexChatUsersOnPseudonym < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :chat_users, [ :chat_id, :pseudonym_key ], unique: true, where: "pseudonym_key IS NOT NULL",
      algorithm: :concurrently, if_not_exists: true
  end
end
