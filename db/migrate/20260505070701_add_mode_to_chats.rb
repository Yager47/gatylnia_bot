class AddModeToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :mode, :integer, null: false, default: 0
  end
end
