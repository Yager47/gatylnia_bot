require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

# Force dummy credentials before Rails boots. dotenv-rails loads .env in the
# test environment too, but never overwrites variables that are already set,
# so this guarantees specs can't reach Telegram/OpenAI with real keys.
# Must happen before boot: BOT_MENTION is built from ENV in an initializer.
ENV["TELEGRAM_BOT_API_TOKEN"] = "test-telegram-token"
ENV["BOT_USERNAME"] = "test_bot"
ENV["OPENAI_API_KEY"] = "test-openai-key"
ENV["TELEGRAM_WEBHOOK_URL"] = "https://example.test/telegram/webhook"
ENV["TELEGRAM_WEBHOOK_SECRET"] = "test-webhook-secret-0123456789abcdef"

require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

# Ensures that the test database schema matches the current schema file.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Each example runs inside a transaction that is rolled back afterwards.
  config.use_transactional_fixtures = true

  config.include FactoryBot::Syntax::Methods

  config.filter_rails_from_backtrace!
end
