# Index for the daily budget lookup (a giver's points since midnight), built
# CONCURRENTLY so writes aren't blocked; that can't run inside a transaction.
# If the build fails it leaves an INVALID index behind: drop it before
# re-running, since if_not_exists would skip it.
#
# Validating the foreign key doesn't block writes to points or users.
class IndexAndValidatePointsGiver < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :points, [ :giver_id, :created_at ], algorithm: :concurrently, if_not_exists: true
    validate_foreign_key :points, :users, column: :giver_id
  end
end
