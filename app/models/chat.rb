class Chat < ApplicationRecord
  has_many :chat_users, dependent: :destroy
  has_many :users, through: :chat_users
  has_many :entries, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :points, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :release_shares, dependent: :destroy

  enum :mode, {
    default: 0,
    accountant: 1,
    quiet: 2
  }

  validates :telegram_id, :telegram_type, :title, :mode, presence: true
end
