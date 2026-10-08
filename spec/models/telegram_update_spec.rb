require "rails_helper"

RSpec.describe TelegramUpdate do
  it "has a valid factory" do
    expect(build(:telegram_update)).to be_valid
  end

  it "starts as received with no attempts" do
    update = create(:telegram_update)

    expect(update).to be_received
    expect(update.attempts).to eq(0)
    expect(update.last_error).to be_nil
    expect(update.processed_at).to be_nil
  end

  it "requires update_id, update_type and payload" do
    update = described_class.new

    expect(update).not_to be_valid
    expect(update.errors.attribute_names).to include(:update_id, :update_type, :payload)
  end

  it "rejects an unknown status instead of raising" do
    expect(build(:telegram_update, status: "bogus")).not_to be_valid
  end

  it "stores update_ids beyond the 32-bit integer range" do
    update = create(:telegram_update, update_id: 3_000_000_000)

    expect(update.reload.update_id).to eq(3_000_000_000)
  end

  it "round-trips the payload as JSON" do
    update = create(:telegram_update, payload: { "update_id" => 1, "message" => { "text" => "Привіт 👋" } })

    expect(update.reload.payload).to eq("update_id" => 1, "message" => { "text" => "Привіт 👋" })
  end

  describe "update_id uniqueness" do
    it "is enforced by the database, so a duplicate insert raises" do
      create(:telegram_update, update_id: 42)

      expect { create(:telegram_update, update_id: 42) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "lets insert_all skip duplicates without raising" do
      create(:telegram_update, update_id: 42)
      row = { update_id: 42, update_type: "message", payload: { "update_id" => 42 } }

      result = described_class.insert_all([ row ], unique_by: :update_id, returning: :id)

      expect(result.rows).to be_empty
      expect(described_class.where(update_id: 42).count).to eq(1)
    end
  end
end
