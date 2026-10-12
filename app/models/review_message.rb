class ReviewMessage < ApplicationRecord
  belongs_to :review
  belongs_to :release_share

  enum :source, { text: 0, voice: 1, video_note: 2 }, prefix: true, validate: true

  validates :telegram_message_id, :text, :sent_at, presence: true
end
