class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :telegram_id, null: false
      t.string :username
      t.string :first_name
      t.string :last_name
      t.references :chat, null: false, foreign_key: true

      t.timestamps
    end
  end
end
