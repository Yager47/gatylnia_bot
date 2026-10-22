require "rails_helper"

RSpec.describe Activities::Recorder do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, chats: [ chat ]) }
  let(:sent_at) { Time.zone.local(2026, 10, 12, 8, 15) }

  def record(kind: :coffee, telegram_message_id: 42, **options)
    described_class.new(
      user: user, chat: chat, kind: kind, source: :video_note,
      telegram_message_id: telegram_message_id, occurred_at: sent_at, **options
    ).call
  end

  it "records the activity and reports it as new" do
    activity = record(amount: 2, details: { "ordinal" => 2 })

    expect(activity).to eq(Activity.last)
    expect(activity).to have_attributes(
      user: user, chat: chat, kind: "coffee", source: "video_note",
      telegram_message_id: 42, occurred_at: sent_at, amount: 2, details: { "ordinal" => 2 }
    )
  end

  it "pays the reward once, not again for a repeated call" do
    record
    record

    expect(Point.sole).to have_attributes(user: user, chat: chat, amount: 25, activity: Activity.sole)
  end

  it "records nothing new for the same message and kind a second time" do
    record

    expect { expect(record).to be_nil }.not_to change(Activity, :count)
  end

  it "records coffee and push-ups from the same message separately" do
    expect(record(kind: :coffee)).to be_a(Activity)
    expect(record(kind: :push_ups)).to be_a(Activity)
  end

  it "keeps the surrounding transaction usable after a duplicate" do
    Activity.transaction do
      record
      record

      # A duplicate INSERT without a savepoint would abort the transaction
      # and make this query raise.
      expect(Activity.count).to eq(1)
    end
  end

  it "rejects invalid activities" do
    expect { record(kind: :push_ups, amount: 20) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
