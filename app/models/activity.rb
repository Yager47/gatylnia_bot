class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :chat

  enum :kind, { coffee: 0, push_ups: 1 }
  enum :source, { text: 0, video_note: 1 }, prefix: true

  validates :kind, :source, :telegram_message_id, :occurred_at, presence: true
  validates :amount, numericality: { only_integer: true, greater_than: 0 }
  # Push-ups track only the fact of doing them, never a rep count.
  validates :amount, numericality: { equal_to: 1 }, if: :push_ups?
end
