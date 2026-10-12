# Data fix: Telegram's service accounts were recorded as chat members before
# the dispatcher started ignoring their messages. Production had one:
# GroupAnonymousBot ("Group") in two chats, owning no rows.
#
# Plain SQL so this keeps working as the models change. Users are deleted only
# if nothing references them; memberships are removed either way.
class RemoveTelegramServiceAccountsFromChats < ActiveRecord::Migration[8.1]
  SERVICE_ACCOUNT_TELEGRAM_IDS = %w[
    1087968824
    136817688
    777000
  ].freeze # GroupAnonymousBot, Channel_Bot, Telegram

  def up
    ids = SERVICE_ACCOUNT_TELEGRAM_IDS.map { |id| connection.quote(id) }.join(", ")

    execute <<~SQL
      DELETE FROM chat_users
      WHERE user_id IN (SELECT id FROM users WHERE telegram_id IN (#{ids}))
    SQL

    execute <<~SQL
      DELETE FROM users
      WHERE telegram_id IN (#{ids})
        AND NOT EXISTS (SELECT 1 FROM messages WHERE messages.user_id = users.id)
        AND NOT EXISTS (SELECT 1 FROM entries WHERE entries.user_id = users.id)
        AND NOT EXISTS (SELECT 1 FROM points WHERE points.user_id = users.id)
        AND NOT EXISTS (SELECT 1 FROM activities WHERE activities.user_id = users.id)
    SQL
  end

  # Nothing to restore: the removed rows were never real members.
  def down; end
end
