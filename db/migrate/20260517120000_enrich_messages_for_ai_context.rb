class EnrichMessagesForAiContext < ActiveRecord::Migration[8.0]
  def change
    change_table :messages, bulk: true do |t|
      t.bigint :telegram_message_id
      t.references :reply_to, foreign_key: { to_table: :messages }
      t.jsonb :reactions, null: false, default: {}
      t.jsonb :reply_snapshot
    end

    add_index :messages, %i[chat_id telegram_message_id],
              unique: true,
              where: "telegram_message_id IS NOT NULL",
              name: "index_messages_on_chat_id_and_telegram_message_id"
  end
end
