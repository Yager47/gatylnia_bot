class ReleaseShare < ApplicationRecord
  belongs_to :chat
  belongs_to :release
  belongs_to :user
  has_many :review_messages, dependent: :restrict_with_exception

  validates :telegram_message_id, :shared_at, presence: true
end
