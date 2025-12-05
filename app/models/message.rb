class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :user, optional: true

  enum :role, {
    user: 0,
    assistant: 1
  }

  validates :role, presence: true
end
