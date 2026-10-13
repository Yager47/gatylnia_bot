# The Kyiv date of the last Camerton reminder digest, so a chat gets at most
# one a day. Nullable without a default: a catalog-only change, safe in one
# step (and chats has one row per group).
class AddCamertonDigestSentOnToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :camerton_digest_sent_on, :date
  end
end
