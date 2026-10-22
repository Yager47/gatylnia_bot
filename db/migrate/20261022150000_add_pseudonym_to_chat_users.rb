# A member's pseudonym in one chat, bought for 500 жмихкоїнів and shown in
# the bot's replies instead of their Telegram name, and its lowercased form
# for uniqueness. Lowercased in Ruby, not with LOWER(): a database with the
# C locale (like local ones) leaves Cyrillic as it is. Nullable with no
# default, so adding them touches only the catalog.
class AddPseudonymToChatUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :chat_users, :pseudonym, :string
    add_column :chat_users, :pseudonym_key, :string
  end
end
