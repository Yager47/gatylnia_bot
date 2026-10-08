require "rails_helper"

RSpec.describe ProcessTelegramUpdateJob do
  let(:dispatcher) { instance_double(TelegramUpdates::Dispatcher, call: true) }

  before do
    allow(TelegramUpdates::Dispatcher).to receive(:new).and_return(dispatcher)
  end

  it "dispatches the stored payload and marks the update processed" do
    update = create(:telegram_update)

    freeze_time do
      described_class.perform_now(update.id)

      expect(update.reload).to have_attributes(status: "processed", processed_at: Time.current)
    end
    expect(TelegramUpdates::Dispatcher).to have_received(:new).with(update.payload)
  end

  it "marks the update ignored when no handler takes it" do
    allow(dispatcher).to receive(:call).and_return(false)
    update = create(:telegram_update)

    described_class.perform_now(update.id)

    expect(update.reload).to be_ignored
    expect(update.processed_at).to be_present
  end

  it "does nothing when run again for a finished update" do
    update = create(:telegram_update)

    2.times { described_class.perform_now(update.id) }

    expect(dispatcher).to have_received(:call).once
  end

  it "leaves the update received when the handler raises, so a redelivery retries it" do
    allow(dispatcher).to receive(:call).and_raise(RuntimeError, "boom")
    update = create(:telegram_update)

    expect { described_class.perform_now(update.id) }.to raise_error(RuntimeError, "boom")

    expect(update.reload).to be_received
  end
end
