# achievements is new and tiny, and a nullable column without a default is
# metadata-only: no rewrite, no long lock. One step.
class AddLevelToAchievements < ActiveRecord::Migration[8.1]
  def change
    # How far along an achievement that grows is: changes of score this
    # week for Перевзувач. Nil for plain ones.
    add_column :achievements, :level, :integer
  end
end
