class Chat < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :entries, dependent: :destroy

  validates :telegram_id, :telegram_type, :title, presence: true
end
