# "@<bot username>", lowercased to match against downcased message text.
#
# Read on first use rather than at boot, so tasks that boot the app without
# Telegram settings (db:test:prepare in CI) still work. A missing
# BOT_USERNAME raises instead of leaving a bare "@" that matches any mention.
module BotMention
  def self.text
    @text ||= "@#{ENV.fetch('BOT_USERNAME').downcase}"
  end
end
