class CreateAudioTracks < ActiveRecord::Migration[8.1]
  def change
    # One per audio message (a demo or mix of the band's own track) in a chat
    # with notes on; replies to it are notes on that version.
    create_table :audio_tracks do |t|
      t.references :chat, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.bigint :telegram_message_id, null: false
      # What Telegram knows about the file, for naming it in the notes list.
      t.string :title
      t.string :performer
      t.string :file_name
      t.text :caption
      t.integer :duration
      t.datetime :sent_at, null: false

      t.timestamps
    end

    # New, empty table: a plain index is fine. It also finds the track a reply
    # points to.
    add_index :audio_tracks, [ :chat_id, :telegram_message_id ], unique: true
  end
end
