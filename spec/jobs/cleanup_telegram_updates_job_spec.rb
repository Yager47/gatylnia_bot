require "rails_helper"

RSpec.describe CleanupTelegramUpdatesJob do
  let(:expired) { (described_class::RETENTION + 1.day).ago }
  let(:recent) { (described_class::RETENTION - 1.day).ago }

  def update_created_at(time, status:)
    create(:telegram_update, status: status, created_at: time)
  end

  it "deletes finished updates older than RETENTION" do
    update_created_at(expired, status: :processed)
    update_created_at(expired, status: :ignored)

    described_class.perform_now

    expect(TelegramUpdate.count).to eq(0)
  end

  it "keeps finished updates within RETENTION" do
    kept = update_created_at(recent, status: :processed)

    described_class.perform_now

    expect(TelegramUpdate.all).to contain_exactly(kept)
  end

  it "keeps failed and unfinished updates whatever their age" do
    kept = %i[failed received processing].map { |status| update_created_at(expired, status: status) }

    described_class.perform_now

    expect(TelegramUpdate.all).to match_array(kept)
  end

  it "deletes across several batches" do
    stub_const("#{described_class}::BATCH_SIZE", 2)
    5.times { update_created_at(expired, status: :processed) }
    kept = update_created_at(recent, status: :processed)

    described_class.perform_now

    expect(TelegramUpdate.all).to contain_exactly(kept)
  end

  describe "schedule" do
    it "is registered as a valid daily recurring task in production" do
      config = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).fetch("production")
      task = SolidQueue::RecurringTask.from_configuration("cleanup_telegram_updates", **config.fetch("cleanup_telegram_updates").symbolize_keys)

      expect(task).to be_valid
      expect(task.class_name).to eq("CleanupTelegramUpdatesJob")
    end
  end
end
