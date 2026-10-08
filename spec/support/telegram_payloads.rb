# Builders for Telegram webhook payloads, shaped like the Bot API's Update
# object: https://core.telegram.org/bots/api#update
module TelegramPayloads
  def telegram_from(id: 555, first_name: "Петро", last_name: "Тест", username: "petro")
    { id: id, is_bot: false, first_name: first_name, last_name: last_name, username: username }
  end

  def telegram_chat(id: -1_001_234_567_890, type: "supergroup", title: "Гатильня")
    { id: id, type: type, title: title }.compact
  end

  def telegram_message(text:, message_id: 42, date: Time.current.to_i, chat: telegram_chat, from: telegram_from, **extra)
    { message_id: message_id, date: date, chat: chat, from: from, text: text, **extra }
  end

  def message_update(update_id: 1, **message_attrs)
    { update_id: update_id, message: telegram_message(**message_attrs) }
  end

  def edited_message_update(update_id: 1, edit_date: Time.current.to_i, **message_attrs)
    { update_id: update_id, edited_message: telegram_message(edit_date: edit_date, **message_attrs) }
  end
end

RSpec.configure { |config| config.include TelegramPayloads }
