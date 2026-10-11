require "rails_helper"

RSpec.describe ProcessTelegramUpdateJob do
  let(:dispatcher) { instance_double(TelegramUpdates::Dispatcher, call: true) }

  before do
    allow(TelegramUpdates::Dispatcher).to receive(:new).and_return(dispatcher)
  end

  def perform(update)
    described_class.perform_now(update.id)
  end

  describe "processing" do
    it "dispatches the stored payload and marks the update processed" do
      update = create(:telegram_update)

      freeze_time do
        perform(update)

        expect(update.reload).to have_attributes(status: "processed", processed_at: Time.current, attempts: 1)
      end
      expect(TelegramUpdates::Dispatcher).to have_received(:new).with(update.payload)
    end

    it "marks the update ignored when no handler takes it" do
      allow(dispatcher).to receive(:call).and_return(false)
      update = create(:telegram_update)

      perform(update)

      expect(update.reload).to be_ignored
      expect(update.processed_at).to be_present
    end

    it "clears the error from a previous failed attempt" do
      update = create(:telegram_update, status: :failed, attempts: 1, last_error: "RuntimeError: boom")

      perform(update)

      expect(update.reload).to have_attributes(status: "processed", attempts: 2, last_error: nil)
    end
  end

  describe "claiming" do
    it "does nothing when run again for a finished update" do
      update = create(:telegram_update)

      2.times { perform(update) }

      expect(dispatcher).to have_received(:call).once
      expect(update.reload.attempts).to eq(1)
    end

    it "skips an ignored update" do
      update = create(:telegram_update, status: :ignored)

      perform(update)

      expect(dispatcher).not_to have_received(:call)
    end

    it "skips an update another run is processing right now" do
      update = create(:telegram_update, status: :processing, attempts: 1)

      perform(update)

      expect(dispatcher).not_to have_received(:call)
      expect(update.reload).to have_attributes(status: "processing", attempts: 1)
    end

    it "reclaims an update stuck in processing for longer than STALE_AFTER" do
      update = create(:telegram_update, status: :processing, attempts: 1)
      update.update_columns(updated_at: (described_class::STALE_AFTER + 1.minute).ago)

      perform(update)

      expect(dispatcher).to have_received(:call).once
      expect(update.reload).to have_attributes(status: "processed", attempts: 2)
    end

    it "retries a failed update" do
      update = create(:telegram_update, status: :failed, attempts: 2)

      perform(update)

      expect(dispatcher).to have_received(:call).once
    end

    it "gives up after MAX_ATTEMPTS" do
      update = create(:telegram_update, status: :failed, attempts: described_class::MAX_ATTEMPTS)

      perform(update)

      expect(dispatcher).not_to have_received(:call)
      expect(update.reload).to have_attributes(status: "failed", attempts: described_class::MAX_ATTEMPTS)
    end
  end

  describe "failure" do
    it "records the error, counts the attempt and re-raises" do
      allow(dispatcher).to receive(:call).and_raise(RuntimeError, "boom")
      update = create(:telegram_update)

      expect { perform(update) }.to raise_error(RuntimeError, "boom")

      expect(update.reload).to have_attributes(status: "failed", attempts: 1, last_error: "RuntimeError: boom", processed_at: nil)
    end

    it "does not retry an error that won't pass on its own" do
      allow(dispatcher).to receive(:call).and_raise(RuntimeError, "boom")
      update = create(:telegram_update)

      expect { perform(update) }.to raise_error(RuntimeError)

      expect(described_class).not_to have_been_enqueued
    end

    it "rolls back the handler's writes so a retry starts clean" do
      chat = create(:chat)
      user = create(:user)
      allow(dispatcher).to receive(:call) do
        Point.create!(chat: chat, user: user, amount: -10, reason: "RPS")
        raise "send_message failed"
      end
      update = create(:telegram_update)

      expect { perform(update) }.to raise_error(RuntimeError, "send_message failed")

      expect(Point.count).to eq(0)
      expect(update.reload).to be_failed
    end
  end

  describe "retries" do
    def telegram_error(code)
      response = instance_double(Faraday::Response, status: code, body: { ok: false, error_code: code, description: "error #{code}" }.to_json)
      Telegram::Bot::Exceptions::ResponseError.new(response: response)
    end

    [
      [ "a connection failure", -> { Faraday::ConnectionFailed.new("down") } ],
      [ "a timeout", -> { Faraday::TimeoutError.new("slow") } ],
      [ "an OpenAI connection error", -> { OpenAI::Errors::APIConnectionError.new(url: URI("https://api.openai.com")) } ]
    ].each do |description, error|
      it "schedules a retry after #{description} and records it as failed" do
        allow(dispatcher).to receive(:call).and_raise(error.call)
        update = create(:telegram_update)

        perform(update)

        expect(described_class).to have_been_enqueued.with(update.id)
        expect(update.reload).to have_attributes(status: "failed", attempts: 1)
      end
    end

    [ 429, 500, 502 ].each do |code|
      it "retries a Telegram #{code}" do
        allow(dispatcher).to receive(:call).and_raise(telegram_error(code))
        update = create(:telegram_update)

        perform(update)

        expect(described_class).to have_been_enqueued.with(update.id)
        expect(update.reload.last_error).to include("error_code: #{code}")
      end
    end

    it "does not retry a permanent Telegram error such as 400" do
      allow(dispatcher).to receive(:call).and_raise(telegram_error(400))
      update = create(:telegram_update)

      expect { perform(update) }.to raise_error(Telegram::Bot::Exceptions::ResponseError)

      expect(described_class).not_to have_been_enqueued
      expect(update.reload).to be_failed
    end

    it "runs the whole retry chain, then gives up after MAX_ATTEMPTS" do
      allow(dispatcher).to receive(:call).and_raise(Faraday::ConnectionFailed, "down")
      update = create(:telegram_update)

      described_class.perform_later(update.id)

      # Each run fails and schedules the next one, until the last re-raises.
      (described_class::MAX_ATTEMPTS - 1).times { perform_enqueued_jobs }
      expect { perform_enqueued_jobs }.to raise_error(Faraday::ConnectionFailed)

      expect(dispatcher).to have_received(:call).exactly(described_class::MAX_ATTEMPTS).times
      expect(update.reload).to have_attributes(status: "failed", attempts: described_class::MAX_ATTEMPTS)
    end
  end
end
