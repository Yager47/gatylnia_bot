class ProcessTelegramUpdateJob < ApplicationJob
  queue_as :default

  # Safe to run twice in a row: a finished update is skipped. Two runs at the
  # same moment can still both process it; claiming the row comes in step 4.
  def perform(telegram_update_id)
    update = TelegramUpdate.find(telegram_update_id)
    return unless update.received?

    handled = TelegramUpdates::Dispatcher.new(update.payload).call
    update.update!(status: handled ? :processed : :ignored, processed_at: Time.current)
  end
end
