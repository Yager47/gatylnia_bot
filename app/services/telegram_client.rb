require "telegram/bot"

class TelegramClient
  def self.build
    Telegram::Bot::Client.new(ENV.fetch("TELEGRAM_BOT_API_TOKEN"))
  end
end
