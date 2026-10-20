class Achievement < ApplicationRecord
  belongs_to :chat
  belongs_to :user

  validates :code, :period, :awarded_at, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def revoked?
    revoked_at.present?
  end
end
