class ReleaseShare < ApplicationRecord
  belongs_to :chat
  belongs_to :release
  belongs_to :user
  has_many :review_messages, dependent: :restrict_with_exception

  validates :telegram_message_id, :shared_at, presence: true

  # The share a reply is about: replying to the link message itself or to
  # the bot's announcement under it.
  scope :replied_to, ->(telegram_message_id) {
    where(telegram_message_id: telegram_message_id).or(where(announcement_telegram_message_id: telegram_message_id))
  }
end
