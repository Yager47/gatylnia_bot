# Who gave a point by replying with a number, for the daily budget. Nullable
# with no default, so adding it touches only the catalog; older points, RPS
# results and bugging fees have no giver and stay NULL.
#
# The foreign key goes in unvalidated so adding it doesn't scan points under
# a lock; the next migration validates it.
class AddGiverToPoints < ActiveRecord::Migration[8.1]
  def change
    add_reference :points, :giver, index: false, foreign_key: { to_table: :users, validate: false }
  end
end
