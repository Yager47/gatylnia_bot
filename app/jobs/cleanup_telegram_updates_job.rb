class CleanupTelegramUpdatesJob < ApplicationJob
  queue_as :default

  # Deduplication only needs a little over 24 hours (Telegram stops
  # redelivering after that); the rest is kept for debugging.
  RETENTION = 30.days
  BATCH_SIZE = 1_000

  # Deletes finished updates in short batches rather than one long DELETE.
  # Failed or unfinished updates are kept as evidence, whatever their age.
  def perform
    TelegramUpdate.finished
      .where(created_at: ...RETENTION.ago)
      .in_batches(of: BATCH_SIZE)
      .delete_all
  end
end
