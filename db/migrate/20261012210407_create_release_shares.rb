class CreateReleaseShares < ActiveRecord::Migration[8.1]
  def change
    # One per message that shared a release; replies to that message are
    # feedback on the release.
    create_table :release_shares do |t|
      t.references :chat, null: false, foreign_key: true, index: false
      t.references :release, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :telegram_message_id, null: false
      t.datetime :shared_at, null: false
      # When the bot replied with the release name; set once, so it replies once.
      t.datetime :announced_at

      t.timestamps
    end

    # New, empty table: plain indexes are fine. The unique one also finds the
    # share a reply points to; the second serves reminders and stats by date.
    add_index :release_shares, [ :chat_id, :telegram_message_id ], unique: true
    add_index :release_shares, [ :chat_id, :shared_at ]
  end
end
