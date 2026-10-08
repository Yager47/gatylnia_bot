class CreateTelegramUpdates < ActiveRecord::Migration[8.0]
  def change
    create_table :telegram_updates do |t|
      t.bigint :update_id, null: false
      t.string :update_type, null: false
      t.jsonb :payload, null: false
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :processed_at

      t.timestamps
    end

    # Telegram's idempotency key: duplicate deliveries must hit this, not a
    # model validation (which is a racy SELECT-then-INSERT).
    add_index :telegram_updates, :update_id, unique: true
    # For the retention cleanup job (step 7). Free to add while the table is empty.
    add_index :telegram_updates, :created_at
  end
end
