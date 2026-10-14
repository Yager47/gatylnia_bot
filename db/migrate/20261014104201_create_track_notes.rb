class CreateTrackNotes < ActiveRecord::Migration[8.1]
  def change
    # Exactly what a member said in one reply to a track (a transcript for
    # voice and video notes).
    create_table :track_notes do |t|
      t.references :audio_track, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.bigint :telegram_message_id, null: false
      t.integer :source, null: false
      t.text :text, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end

    # New, empty table: a plain index is fine. A reply belongs to one track, so
    # this also finds the row an edit updates, and lists a track's notes.
    add_index :track_notes, [ :audio_track_id, :telegram_message_id ], unique: true
  end
end
