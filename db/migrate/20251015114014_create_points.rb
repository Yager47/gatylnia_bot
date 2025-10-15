class CreatePoints < ActiveRecord::Migration[8.0]
  def change
    create_table :points do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chat, null: false, foreign_key: true
      t.integer :amount, null: false, default: 0
      t.string :reason

      t.timestamps
    end
  end
end
