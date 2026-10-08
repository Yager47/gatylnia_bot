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
end
