# A nullable column with no default is metadata-only on PostgreSQL (no table
# rewrite, a brief lock), and chats is tiny, so one step is safe here.
class AddSupergroupSinceToChats < ActiveRecord::Migration[8.1]
  def change
    # When a basic group became this supergroup. Messages from before it have
    # the old group's ids, which no t.me/c link can reach.
    add_column :chats, :supergroup_since, :datetime
  end
end
