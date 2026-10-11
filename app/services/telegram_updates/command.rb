module TelegramUpdates
  # Extracts the bot command a message starts with, based on Telegram's
  # bot_command entity. Returns the command name ("ping"), or nil when the
  # message doesn't start with a command addressed to this bot.
  module Command
    def self.parse(message, bot_username: ENV.fetch("BOT_USERNAME"))
      return unless Array(message[:entities]).any? { |entity| entity[:type] == "bot_command" }

      # The command must be the first token. Entity offsets and lengths are in
      # UTF-16 code units, not Ruby characters, so match the text directly
      # instead of slicing by offset.
      token = message[:text].to_s[%r{\A/\S+}]
      return unless token

      name, target = token.delete_prefix("/").split("@", 2)
      return if target && !target.casecmp?(bot_username)

      name.downcase
    end
  end
end
