# releases is small (about 2k rows), but this follows the safe pattern
# anyway: a nullable column with no default is metadata-only, the index is
# built concurrently, and the foreign key is validated in a separate step
# that doesn't block writes.
class AddMergedIntoToReleases < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # The release this one duplicates (same kind, artist and title). A merged
    # release keeps no shares or reviews; it only maps its link to the other.
    add_column :releases, :merged_into_id, :bigint
    add_index :releases, :merged_into_id, algorithm: :concurrently
    add_foreign_key :releases, :releases, column: :merged_into_id, validate: false
    validate_foreign_key :releases, :releases, column: :merged_into_id
  end
end
