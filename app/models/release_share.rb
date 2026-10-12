class ReleaseShare < ApplicationRecord
  belongs_to :chat
  belongs_to :release
  belongs_to :user

  validates :telegram_message_id, :shared_at, presence: true
end
