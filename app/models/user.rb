class User < ApplicationRecord
  has_many :chat_users, dependent: :destroy
  has_many :chats, through: :chat_users
  has_many :entries, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :points, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :release_shares, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :audio_tracks, dependent: :destroy
  has_many :track_notes, dependent: :destroy
  has_many :achievements, dependent: :destroy

  validates :telegram_id, presence: true

  def name
    [ first_name, last_name ].compact.join(" ")
  end
end
