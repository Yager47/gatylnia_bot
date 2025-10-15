class Point < ApplicationRecord
  belongs_to :user
  belongs_to :chat

  validates :amount, presence: true
end
