class Chat < ApplicationRecord
  has_many :chat_users, dependent: :destroy
  has_many :users, through: :chat_users
  has_many :entries, dependent: :destroy
  has_many :points, dependent: :destroy

  validates :telegram_id, :telegram_type, :title, presence: true
end
