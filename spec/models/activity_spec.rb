require "rails_helper"

RSpec.describe Activity do
  it "has a valid factory" do
    expect(build(:activity)).to be_valid
    expect(build(:activity, :push_ups)).to be_valid
  end

  it "counts one cup by default" do
    expect(create(:activity).amount).to eq(1)
  end

  it "allows several cups in one coffee activity" do
    expect(build(:activity, amount: 2)).to be_valid
  end

  it "rejects a zero or negative amount" do
    expect(build(:activity, amount: 0)).not_to be_valid
    expect(build(:activity, amount: -1)).not_to be_valid
  end

  it "rejects a rep count on push-ups" do
    expect(build(:activity, :push_ups, amount: 20)).not_to be_valid
  end

  it "requires the Telegram message and when it happened" do
    activity = build(:activity, telegram_message_id: nil, occurred_at: nil)

    expect(activity).not_to be_valid
    expect(activity.errors.attribute_names).to include(:telegram_message_id, :occurred_at)
  end

  describe "unique index on chat, message and kind" do
    let(:first) { create(:activity) }

    it "rejects a second activity of the same kind for the same message" do
      duplicate = build(:activity, chat: first.chat, telegram_message_id: first.telegram_message_id)

      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows coffee and push-ups from the same video note" do
      push_ups = build(:activity, :push_ups, chat: first.chat, telegram_message_id: first.telegram_message_id)

      expect(push_ups.save).to be(true)
    end

    it "allows the same message id in another chat" do
      other_chat = build(:activity, telegram_message_id: first.telegram_message_id)

      expect(other_chat.save).to be(true)
    end
  end
end
