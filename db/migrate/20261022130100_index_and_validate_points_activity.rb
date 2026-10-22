# Index for finding an activity's reward (and for the foreign key when an
# activity is deleted), built CONCURRENTLY so writes aren't blocked; that
# can't run inside a transaction. If the build fails it leaves an INVALID
# index behind: drop it before re-running, since if_not_exists would skip it.
#
# Validating the foreign key doesn't block writes to points or activities.
class IndexAndValidatePointsActivity < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :points, :activity_id, unique: true, algorithm: :concurrently, if_not_exists: true
    validate_foreign_key :points, :activities
  end
end
