# reviews is small (under 2k rows), and on PostgreSQL 11+ a column with a
# constant default is metadata-only: no table rewrite, no long lock, and the
# NOT NULL holds at once because every row reads the default. So one step
# rather than the add-backfill-constrain pattern.
class AddSourceToReviews < ActiveRecord::Migration[8.1]
  def change
    # Where the score came from: replies in the chat (telegram) or a member's
    # ratings spreadsheet (Camerton::RatingsImport).
    add_column :reviews, :source, :integer, default: 0, null: false
  end
end
