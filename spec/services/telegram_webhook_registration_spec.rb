require "rails_helper"

RSpec.describe TelegramWebhookRegistration do
  let(:url) { "https://bot.example.test/telegram/webhook" }
  let(:secret) { "a" * 32 }

  def registration(secret_token: secret)
    described_class.new(url: url, secret_token: secret_token)
  end

  describe "#register" do
    it "sets the webhook with the secret token and allowed updates" do
      registration.register

      expect(fake_telegram.calls).to eq([
        [ :set_webhook, {
          url: url,
          secret_token: secret,
          allowed_updates: %w[message edited_message message_reaction message_reaction_count]
        } ]
      ])
    end
  end

  describe "#reset" do
    it "drops pending updates before registering again" do
      registration.reset

      expect(fake_telegram.calls.map(&:first)).to eq([ :delete_webhook, :set_webhook ])
      expect(fake_telegram.calls.first.last).to eq(drop_pending_updates: true)
      expect(fake_telegram.calls.last.last).to include(secret_token: secret)
    end
  end

  describe "secret token validation" do
    it "accepts the full allowed alphabet" do
      expect { registration(secret_token: "Az09_-" * 6) }.not_to raise_error
    end

    [
      [ "missing", nil ],
      [ "empty", "" ],
      [ "shorter than 32 characters", "a" * 31 ],
      [ "longer than 256 characters", "a" * 257 ],
      [ "containing characters Telegram rejects", "#{'a' * 31}!" ],
      [ "containing a newline", "#{'a' * 32}\n" ]
    ].each do |description, value|
      it "rejects a token #{description} before calling Telegram" do
        expect { registration(secret_token: value) }.to raise_error(ArgumentError, /secret_token/)
        expect(fake_telegram.calls).to be_empty
      end
    end
  end
end
