class User < ApplicationRecord
  has_many :chat_users, dependent: :destroy
  has_many :chats, through: :chat_users
  has_many :entries, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :points, dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :telegram_id, presence: true

  def name
    [ first_name, last_name ].compact.join(" ")
  end
end
