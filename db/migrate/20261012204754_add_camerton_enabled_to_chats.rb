# A constant default is metadata-only on PostgreSQL 11+ (no table rewrite),
# and chats has one row per group, so one step is safe here.
class AddCamertonEnabledToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :camerton_enabled, :boolean, null: false, default: false
  end
end
