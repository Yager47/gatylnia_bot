class ProcessTelegramUpdateJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 5
  # A run that has been `processing` this long is assumed dead (dyno restart,
  # crash) and may be claimed again.
  STALE_AFTER = 10.minutes

  def perform(telegram_update_id)
    unless claim(telegram_update_id)
      Rails.logger.info("[ProcessTelegramUpdateJob] TelegramUpdate #{telegram_update_id} not claimable, skipping")
      return
    end

    process(TelegramUpdate.find(telegram_update_id))
  end

  private

  # One UPDATE statement, so two runs can't both claim the same update: the
  # second waits for the first's row lock, re-checks the WHERE clause and
  # updates nothing.
  def claim(id)
    now = Time.current
    claimable = TelegramUpdate.where(status: [ :received, :failed ])
      .or(TelegramUpdate.where(status: :processing, updated_at: ...(now - STALE_AFTER)))

    TelegramUpdate
      .where(id: id, attempts: ...MAX_ATTEMPTS)
      .and(claimable)
      .update_all([ "status = ?, attempts = attempts + 1, updated_at = ?", TelegramUpdate.statuses[:processing], now ]) == 1
  end

  # Handlers write points, entries and messages before sending the reply. If
  # anything raises (most likely send_message), those writes roll back so a
  # retry starts clean. If the send succeeds but the commit fails, a retry
  # sends the reply again; that rare case is accepted.
  def process(update)
    TelegramUpdate.transaction do
      handled = TelegramUpdates::Dispatcher.new(update.payload).call
      update.update!(status: handled ? :processed : :ignored, processed_at: Time.current, last_error: nil)
    end
  rescue StandardError => e
    update.update!(status: :failed, last_error: "#{e.class}: #{e.message}".truncate(1_000))
    raise
  end
end
