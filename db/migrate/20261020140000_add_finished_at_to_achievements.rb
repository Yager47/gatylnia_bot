# achievements is new and tiny, and a nullable column without a default is
# metadata-only: no rewrite, no long lock. One step.
class AddFinishedAtToAchievements < ActiveRecord::Migration[8.1]
  def change
    # When a Серія ended (a day without a review). Unlike revoked_at, the
    # streak still counts as earned.
    add_column :achievements, :finished_at, :datetime
  end
end
