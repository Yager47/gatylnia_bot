# Nullable columns with no default are metadata-only on PostgreSQL (no table
# rewrite, a brief lock), and no index is added, so one step is safe here.
class AddDiscogsDetailsToReleases < ActiveRecord::Migration[8.1]
  def change
    change_table :releases, bulk: true do |t|
      # The master release Discogs matched, kept to check a wrong match.
      t.bigint :discogs_master_id
      # Original release year; for a song, its album's (or single's).
      t.integer :year
      # For a song: the studio album it first came out on.
      t.string :album_title
      t.string :genres, array: true
      t.string :styles, array: true
      # Set once Discogs answered, found or not, so it's asked only once.
      t.datetime :discogs_checked_at
    end
  end
end
