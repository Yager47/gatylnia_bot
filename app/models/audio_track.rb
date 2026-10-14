class AudioTrack < ApplicationRecord
  LABEL_LENGTH = 100

  belongs_to :chat
  belongs_to :user
  has_many :notes, class_name: "TrackNote", dependent: :destroy

  validates :telegram_message_id, :sent_at, presence: true

  # How the notes list names this version: the sender's caption, else the
  # file's tags, else its name.
  def label
    name = caption.presence || [ performer, title ].compact_blank.join(" — ").presence || file_name.presence || "аудіо"
    name.squish.truncate(LABEL_LENGTH)
  end
end
