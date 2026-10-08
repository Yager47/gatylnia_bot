namespace :telegram do
  webhook_registration = lambda do
    TelegramWebhookRegistration.new(
      url: ENV.fetch("TELEGRAM_WEBHOOK_URL"),
      secret_token: ENV.fetch("TELEGRAM_WEBHOOK_SECRET")
    )
  end

  # Prints only the host: the URL path may contain the bot token.
  webhook_host = -> { URI(ENV.fetch("TELEGRAM_WEBHOOK_URL")).host }

  desc "Register webhook with secret token and reaction updates (bot must be chat admin)"
  task configure_webhook: :environment do
    webhook_registration.call.register
    puts "Webhook registered for #{webhook_host.call}"
  end

  desc "Clear pending updates and re-register webhook"
  task reset_webhook: :environment do
    webhook_registration.call.reset
    puts "Pending updates dropped, webhook re-registered for #{webhook_host.call}"
  end
end
