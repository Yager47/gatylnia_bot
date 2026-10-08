require "rails_helper"

RSpec.describe TelegramUpdates::Ingest do
  def ingest(update_id: 100, payload: { "update_id" => update_id, "message" => { "text" => "Ало" } })
    described_class.new(update_id: update_id, payload: payload).call
  end

  it "stores a new update and enqueues its processing" do
    expect(ingest).to eq(:enqueued)

    update = TelegramUpdate.sole
    expect(update).to have_attributes(
      update_id: 100,
      update_type: "message",
      payload: { "update_id" => 100, "message" => { "text" => "Ало" } },
      status: "received"
    )
    expect(ProcessTelegramUpdateJob).to have_been_enqueued.with(update.id).exactly(:once)
  end

  it "derives update_type from the field next to update_id" do
    ingest(update_id: 1, payload: { "update_id" => 1, "message_reaction_count" => {} })

    expect(TelegramUpdate.sole.update_type).to eq("message_reaction_count")
  end

  it "falls back to 'unknown' for a payload with only update_id" do
    ingest(update_id: 1, payload: { "update_id" => 1 })

    expect(TelegramUpdate.sole.update_type).to eq("unknown")
  end

  context "when the update_id was already stored" do
    it "drops the redelivery of a finished update" do
      create(:telegram_update, update_id: 100, status: :processed)

      expect(ingest).to eq(:duplicate)

      expect(TelegramUpdate.count).to eq(1)
      expect(ProcessTelegramUpdateJob).not_to have_been_enqueued
    end

    it "drops the redelivery of an ignored update" do
      create(:telegram_update, update_id: 100, status: :ignored)

      expect(ingest).to eq(:duplicate)
      expect(ProcessTelegramUpdateJob).not_to have_been_enqueued
    end

    %i[received processing failed].each do |status|
      it "re-enqueues an unfinished (#{status}) update and lets the job's claim decide" do
        existing = create(:telegram_update, update_id: 100, status: status)

        expect(ingest).to eq(:requeued)

        expect(TelegramUpdate.count).to eq(1)
        expect(ProcessTelegramUpdateJob).to have_been_enqueued.with(existing.id).exactly(:once)
      end
    end

    it "keeps the originally stored payload" do
      create(:telegram_update, update_id: 100, payload: { "update_id" => 100, "message" => { "text" => "перший" } })

      ingest(payload: { "update_id" => 100, "message" => { "text" => "другий" } })

      expect(TelegramUpdate.sole.payload.dig("message", "text")).to eq("перший")
    end
  end
end
