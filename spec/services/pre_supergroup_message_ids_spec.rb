require "rails_helper"

RSpec.describe PreSupergroupMessageIds do
  let(:upgraded_at) { Time.zone.local(2026, 10, 14, 16, 0) }
  let(:chat) { create(:chat, telegram_type: "supergroup", supergroup_since: upgraded_at) }
  let(:before) { upgraded_at - 1.hour }
  let(:after) { upgraded_at + 1.hour }

  def ids(records)
    records.map { |record| record.reload.telegram_message_id }
  end

  it "negates every message number from before the upgrade and keeps the later ones" do
    old_share = create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: before,
      announcement_telegram_message_id: 15_001, announced_at: before)
    # Shared just before the upgrade, announced just after it.
    late_announced = create(:release_share, chat: chat, telegram_message_id: 15_002, shared_at: before,
      announcement_telegram_message_id: 3, announced_at: after)
    new_share = create(:release_share, chat: chat, telegram_message_id: 4, shared_at: after)
    old_track = create(:audio_track, chat: chat, telegram_message_id: 16_000, sent_at: before)
    new_track = create(:audio_track, chat: chat, telegram_message_id: 5, sent_at: after)
    olds = [
      old_share,
      create(:message, chat: chat, telegram_message_id: 17_000, created_at: before),
      create(:activity, chat: chat, telegram_message_id: 18_000, occurred_at: before),
      old_track,
      create(:review_message, release_share: old_share, review: create(:review, chat: chat, release: old_share.release),
        telegram_message_id: 19_000, sent_at: before),
      create(:track_note, audio_track: old_track, telegram_message_id: 20_000, sent_at: before)
    ]
    news = [
      new_share,
      create(:message, chat: chat, telegram_message_id: 6, created_at: after),
      create(:activity, chat: chat, telegram_message_id: 7, occurred_at: after),
      new_track,
      create(:review_message, release_share: new_share, review: create(:review, chat: chat, release: new_share.release),
        telegram_message_id: 8, sent_at: after),
      create(:track_note, audio_track: new_track, telegram_message_id: 9, sent_at: after)
    ]

    renumbered = described_class.new(chat).call

    expect(ids(olds)).to eq([ -15_000, -17_000, -18_000, -16_000, -19_000, -20_000 ])
    expect(ids(news)).to eq([ 4, 6, 7, 5, 8, 9 ])
    expect(old_share.announcement_telegram_message_id).to eq(-15_001)
    expect(late_announced.reload).to have_attributes(telegram_message_id: -15_002, announcement_telegram_message_id: 3)
    expect(renumbered).to include("release_shares.telegram_message_id" => 2, "release_shares.announcement_telegram_message_id" => 1,
      "messages.telegram_message_id" => 1, "track_notes.telegram_message_id" => 1)
  end

  it "frees the old numbers for the supergroup's own messages" do
    old_share = create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: before)
    described_class.new(chat).call

    new_share = create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: after)

    expect(chat.release_shares.replied_to(15_000)).to eq([ new_share ])
    expect(old_share.reload.telegram_message_id).to eq(-15_000)
  end

  it "is safe to run again, and leaves other chats alone" do
    share = create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: before)
    other = create(:release_share, telegram_message_id: 15_000, shared_at: before)

    described_class.new(chat).call
    expect(described_class.new(chat).call.values).to all(eq(0))

    expect(ids([ share, other ])).to eq([ -15_000, 15_000 ])
  end

  it "does nothing for a chat that never was a basic group" do
    share = create(:release_share, telegram_message_id: 15_000)

    expect(described_class.new(share.chat).call).to eq({})
    expect(described_class.new(share.chat).stats).to eq([])
    expect(share.reload.telegram_message_id).to eq(15_000)
  end

  it "reports each side of the upgrade without changing anything" do
    create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: before)
    create(:release_share, chat: chat, telegram_message_id: 942_676, shared_at: before)
    create(:release_share, chat: chat, telegram_message_id: 90, shared_at: after)

    stats = described_class.new(chat).stats

    expect(stats.find { |s| s.label == "release_shares.telegram_message_id" })
      .to have_attributes(old_count: 2, old_range: 15_000..942_676, new_count: 1, new_range: 90..90)
    expect(stats.find { |s| s.label == "messages.telegram_message_id" }).to have_attributes(old_count: 0, old_range: nil)
    expect(ReleaseShare.pluck(:telegram_message_id)).to all(be_positive)
  end

  describe ".stored" do
    it "negates a number sent before the upgrade" do
      expect(described_class.stored(chat, 15_000, before)).to eq(-15_000)
      expect(described_class.stored(chat, 15_000, upgraded_at)).to eq(15_000)
      expect(described_class.stored(chat, nil, before)).to be_nil
      expect(described_class.stored(build(:chat), 15_000, before)).to eq(15_000)
    end
  end
end
