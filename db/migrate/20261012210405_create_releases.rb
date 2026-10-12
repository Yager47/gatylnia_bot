class CreateReleases < ActiveRecord::Migration[8.1]
  def change
    # A song or album on one platform, shared by any chat. Metadata is filled
    # in by ResolveReleaseJob after the link is seen.
    create_table :releases do |t|
      t.string :platform, null: false
      t.string :external_id, null: false
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.string :url, null: false
      t.string :artist
      t.string :title
      # What the platform returned, kept to re-clean names later if needed.
      t.string :source_title
      t.string :source_author

      t.timestamps
    end

    # New, empty table: plain indexes are fine.
    add_index :releases, [ :platform, :external_id ], unique: true
  end
end
