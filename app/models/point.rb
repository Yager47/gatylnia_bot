class Point < ApplicationRecord
  belongs_to :user
  belongs_to :chat

  validates :amount, numericality: { only_integer: true, other_than: 0 }
end
