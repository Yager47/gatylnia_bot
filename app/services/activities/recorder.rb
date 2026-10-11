module Activities
  # Records one activity per Telegram message and kind. Safe to call twice for
  # the same message (job retries, Telegram's edited re-sends): the second call
  # finds the existing row and reports that nothing new was recorded.
  class Recorder
    def initialize(user:, chat:, kind:, source:, telegram_message_id:, occurred_at:, amount: 1, details: {})
      @user = user
      @chat = chat
      @kind = kind
      @source = source
      @telegram_message_id = telegram_message_id
      @occurred_at = occurred_at
      @amount = amount
      @details = details
    end

    # Returns true if this call recorded the activity, false if it already
    # existed. Callers confirm to the user only on true.
    #
    # create_or_find_by! relies on the unique index and runs the INSERT in a
    # savepoint, so a duplicate doesn't abort the caller's transaction.
    # find_or_create_by! would race: two jobs could both find nothing.
    def call
      activity = Activity.create_or_find_by!(chat: @chat, telegram_message_id: @telegram_message_id, kind: @kind) do |record|
        record.user = @user
        record.source = @source
        record.occurred_at = @occurred_at
        record.amount = @amount
        record.details = @details
      end

      activity.previously_new_record?
    end
  end
end
