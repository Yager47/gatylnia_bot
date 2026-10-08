module TelegramUpdates
  # Stores an incoming update once per update_id and enqueues its processing.
  class Ingest
    def initialize(update_id:, payload:)
      @update_id = update_id
      @payload = payload
    end

    # Returns :enqueued, :requeued or :duplicate.
    def call
      inserted_id = insert
      return enqueue(inserted_id, :enqueued) if inserted_id

      existing = TelegramUpdate.find_by!(update_id: @update_id)
      # A redelivery of an update that isn't finished (the job raised, so
      # Telegram got a non-2xx and retried): enqueue it again and let the
      # job's claim decide whether it may run. Finished updates are dropped.
      existing.finished? ? :duplicate : enqueue(existing.id, :requeued)
    end

    private

    # INSERT ... ON CONFLICT (update_id) DO NOTHING; returns the new id, or nil
    # when the update_id already exists.
    def insert
      TelegramUpdate.insert_all(
        [ { update_id: @update_id, update_type: update_type, payload: @payload } ],
        unique_by: :update_id,
        returning: :id
      ).rows.first&.first
    end

    # Every update has update_id plus exactly one field naming its type.
    def update_type
      (@payload.keys - [ "update_id" ]).first || "unknown"
    end

    def enqueue(id, outcome)
      ProcessTelegramUpdateJob.perform_later(id)
      outcome
    end
  end
end
