class TelegramUpdate < ApplicationRecord
  enum :status, {
    received: 0,
    processing: 1,
    processed: 2,
    failed: 3,
    ignored: 4
  }, validate: true

  # No uniqueness validation on update_id: the unique index enforces it, and
  # ingestion relies on INSERT ... ON CONFLICT DO NOTHING rather than a check.
  validates :update_id, :update_type, :payload, presence: true

  def finished?
    processed? || ignored?
  end
end
