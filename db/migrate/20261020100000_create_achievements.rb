# A new, empty table: creating it and its indexes locks nothing that exists.
class CreateAchievements < ActiveRecord::Migration[8.1]
  def change
    # One row per member, achievement and period. A row whose condition stops
    # holding is revoked (revoked_at), not deleted, and comes back if it holds
    # again. See Achievements::Checker.
    create_table :achievements do |t|
      t.references :chat, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      # "2026-10" for a month, "2026-W43" for a week (Achievements::Period).
      t.string :period, null: false
      t.datetime :awarded_at, null: false
      t.datetime :revoked_at
      t.timestamps

      t.index [ :chat_id, :code, :period, :user_id ], unique: true
    end
  end
end
