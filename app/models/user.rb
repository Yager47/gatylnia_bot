class User < ApplicationRecord
  belongs_to :chat
  has_many :entries, dependent: :destroy

  validates :telegram_id, presence: true

  def name
    [first_name, last_name].compact.join(" ")
  end
end
