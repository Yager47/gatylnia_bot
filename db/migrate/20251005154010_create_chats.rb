class CreateChats < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.string :telegram_id, null: false
      t.string :telegram_type, null: false
      t.string :title

      t.timestamps
    end
  end
end
