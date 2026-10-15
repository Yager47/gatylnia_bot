# A basic group numbers its messages differently from the supergroup it
# becomes, and the supergroup starts again near 1, so its numbers would
# reach the old ones: a reply to new message N would find old share N, and
# new message N couldn't be stored next to it (unique indexes). Negating
# the old numbers keeps them (the absolute value is the old id) where no
# new message can reach, and below every new one, so "is there a later
# message" checks hold.
#
# A row counts as old when it was sent before chat.supergroup_since. Safe
# to run again: only positive numbers change.
class PreSupergroupMessageIds
  Column = Data.define(:label, :scope, :id_column, :time_column)
  Stats = Data.define(:label, :old_count, :old_range, :new_count, :new_range)

  # The id to store for a message from the chat's history (an export, say):
  # negated if it was sent before the chat became a supergroup.
  def self.stored(chat, id, sent_at)
    return id unless id && chat.supergroup_since && sent_at < chat.supergroup_since

    -id
  end

  def initialize(chat)
    @chat = chat
  end

  # Returns {label => rows renumbered}; empty for a chat that never was a
  # basic group.
  def call
    return {} unless @chat.supergroup_since

    ApplicationRecord.transaction do
      columns.to_h do |column|
        [ column.label, old(column).update_all("#{column.id_column} = -#{column.id_column}") ]
      end
    end
  end

  # What #call would change: per column, how many positive numbers fall on
  # each side of supergroup_since and their range. Old numbers should all be
  # bigger than new ones; if not, supergroup_since is off.
  def stats
    return [] unless @chat.supergroup_since

    columns.map do |column|
      Stats.new(column.label, *summary(old(column), column), *summary(current(column), column))
    end
  end

  private

  def columns
    shares = ReleaseShare.where(chat: @chat)
    [
      Column.new("release_shares.telegram_message_id", shares, "telegram_message_id", "shared_at"),
      # The announcement goes out after the share, possibly already in the
      # supergroup.
      Column.new("release_shares.announcement_telegram_message_id", shares, "announcement_telegram_message_id", "announced_at"),
      # No sent_at; created when received (the bot's own: just before sending).
      Column.new("messages.telegram_message_id", Message.where(chat: @chat), "telegram_message_id", "created_at"),
      Column.new("activities.telegram_message_id", Activity.where(chat: @chat), "telegram_message_id", "occurred_at"),
      Column.new("audio_tracks.telegram_message_id", AudioTrack.where(chat: @chat), "telegram_message_id", "sent_at"),
      Column.new("review_messages.telegram_message_id", ReviewMessage.where(release_share: shares), "telegram_message_id", "sent_at"),
      Column.new("track_notes.telegram_message_id", TrackNote.where(audio_track: AudioTrack.where(chat: @chat)), "telegram_message_id", "sent_at")
    ]
  end

  def positive(column)
    column.scope.where(column.id_column => 1..)
  end

  def old(column)
    positive(column).where(column.time_column => ...@chat.supergroup_since)
  end

  def current(column)
    positive(column).where(column.time_column => @chat.supergroup_since..)
  end

  def summary(scope, column)
    count, min, max = scope.pick(Arel.sql("count(*)"), Arel.sql("min(#{column.id_column})"), Arel.sql("max(#{column.id_column})"))
    [ count, (min..max if count.positive?) ]
  end
end
