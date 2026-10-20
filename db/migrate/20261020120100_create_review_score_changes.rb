# A new, empty table: creating it and its index locks nothing that exists.
class CreateReviewScoreChanges < ActiveRecord::Migration[8.1]
  def change
    # Each time a member's reply changed their review's existing score
    # (Camerton::ReviewScoring). Counted by Перевзувач.
    create_table :review_score_changes do |t|
      t.references :review, null: false, foreign_key: true
      t.integer :from_score, null: false
      t.integer :to_score, null: false
      t.datetime :changed_at, null: false
      t.timestamps
    end
  end
end
