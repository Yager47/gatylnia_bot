module GatoHistory
  # Rebuilds a chat's gato entries for a period from exported chat history,
  # using the same rules as Response::Gato: a message that is exactly a gato
  # phrase adds an entry, "видали гатіння" removes the sender's last one.
  # Nothing is sent to the chat.
  #
  # Every entry already in the chat for the period is replaced, so running it
  # twice gives the same result. Entries keep the message's own time, so the
  # period stats come out right.
  class Import
    Report = Data.define(:deleted, :created, :removals, :skipped_senders)

    # from: inclusive, to: exclusive.
    def initialize(chat:, messages:, from:, to:, dry_run: true)
      @chat = chat
      @messages = messages
      @period = from...to
      @dry_run = dry_run
    end

    def call
      entries_by_sender, removals, skipped = replay
      users = @chat.users.where(telegram_id: entries_by_sender.keys).index_by(&:telegram_id)
      skipped.merge!(entries_by_sender.except(*users.keys).transform_values(&:size))

      rows = users.flat_map do |telegram_id, user|
        entries_by_sender[telegram_id].map { |message| entry_row(user, message) }
      end
      existing = @chat.entries.where(created_at: @period)

      report = Report.new(
        deleted: existing.group(:message).count,
        created: users.to_h { |telegram_id, user| [ user, entries_by_sender[telegram_id].size ] },
        removals: removals,
        skipped_senders: skipped
      )
      persist(existing, rows) unless @dry_run
      report
    end

    private

    # Returns gato messages left after removals, per sender id; the number of
    # removals applied; and gato counts for senders without an id (no
    # userpic in the export), keyed by name.
    def replay
      entries = Hash.new { |hash, key| hash[key] = [] }
      removals = 0
      skipped = Hash.new(0)

      @messages.each do |message|
        next unless @period.cover?(message.sent_at) && message.text

        text = message.text.downcase
        if gato_phrases.include?(text)
          message.sender_id ? entries[message.sender_id] << message : skipped[message.sender_name] += 1
        elsif text == Response::Gato::REMOVE_PHRASE && message.sender_id && entries[message.sender_id].pop
          removals += 1
        end
      end

      [ entries.reject { |_, list| list.empty? }, removals, skipped ]
    end

    def entry_row(user, message)
      {
        user_id: user.id,
        chat_id: @chat.id,
        message: message.text,
        created_at: message.sent_at,
        updated_at: message.sent_at
      }
    end

    def persist(existing, rows)
      Entry.transaction do
        existing.delete_all
        Entry.insert_all!(rows) if rows.any?
      end
    end

    def gato_phrases
      @gato_phrases ||= AnswerFiles.yaml("phrases", "gato")
    end
  end
end
