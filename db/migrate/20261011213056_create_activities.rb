class CreateActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      # Covered by the composite indexes below, which both start with chat_id.
      t.references :chat, null: false, foreign_key: true, index: false
      t.integer :kind, null: false
      t.integer :amount, null: false, default: 1
      t.integer :source, null: false
      t.bigint :telegram_message_id, null: false
      # When the user sent the message; the job may run later (retries).
      t.datetime :occurred_at, null: false
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    # One activity of each kind per Telegram message: makes recording
    # idempotent across job retries and Telegram's edited re-sends.
    add_index :activities, [ :chat_id, :telegram_message_id, :kind ], unique: true
    # Stats: equality columns first, the range column last.
    add_index :activities, [ :chat_id, :kind, :occurred_at ]
  end
end
