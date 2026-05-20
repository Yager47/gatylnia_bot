require "telegram/bot"

namespace :telegram do
  desc "Register webhook with reaction updates (bot must be chat admin)"
  task configure_webhook: :environment do
    token = ENV.fetch("TELEGRAM_BOT_API_TOKEN")
    url = ENV.fetch("TELEGRAM_WEBHOOK_URL")
    client = Telegram::Bot::Client.new(token)

    client.api.set_webhook(
      url: url,
      allowed_updates: %w[
        message
        edited_message
        message_reaction
        message_reaction_count
      ]
    )

    puts "Webhook set to #{url}"
  end

  desc "Clear pending updates and re-register webhook"
  task reset_webhook: :environment do
    token = ENV.fetch("TELEGRAM_BOT_API_TOKEN")
    url = ENV.fetch("TELEGRAM_WEBHOOK_URL")
    client = Telegram::Bot::Client.new(token)

    client.api.delete_webhook(drop_pending_updates: true)
    puts "Webhook deleted, pending updates dropped"

    client.api.set_webhook(
      url: url,
      allowed_updates: %w[
        message
        edited_message
        message_reaction
        message_reaction_count
      ]
    )
    puts "Webhook re-registered at #{url}"
  end
end
