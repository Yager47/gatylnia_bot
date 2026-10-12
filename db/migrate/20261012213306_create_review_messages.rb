class CreateReviewMessages < ActiveRecord::Migration[8.1]
  def change
    # Exactly what the member said in one reply (a transcript for voice and
    # video notes), and which share of the release it answered.
    create_table :review_messages do |t|
      t.references :review, null: false, foreign_key: true
      t.references :release_share, null: false, foreign_key: true, index: false
      t.bigint :telegram_message_id, null: false
      t.integer :source, null: false
      t.text :text, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end

    # New, empty table: plain indexes are fine. A Telegram message replies to
    # one share, so this also finds the row an edit belongs to.
    add_index :review_messages, [ :release_share_id, :telegram_message_id ],
      unique: true, name: "index_review_messages_on_share_and_telegram_message"
  end
end
