class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    # One member's opinion of a release in one chat. Every reply they make
    # under any share of it adds a ReviewMessage, and the score is re-derived
    # from all of them.
    create_table :reviews do |t|
      t.references :chat, null: false, foreign_key: true, index: false
      t.references :release, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # 1-10, or null while the messages hold no opinion about the music.
      t.integer :score
      t.string :summary
      t.datetime :scored_at

      t.timestamps
    end

    # New, empty table: plain indexes are fine.
    add_index :reviews, [ :chat_id, :release_id, :user_id ], unique: true
    add_check_constraint :reviews, "score BETWEEN 1 AND 10", name: "reviews_score_range"
  end
end
