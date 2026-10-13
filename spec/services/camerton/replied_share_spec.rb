require "rails_helper"

RSpec.describe Camerton::RepliedShare do
  let(:chat) { create(:chat) }
  let(:release) { create(:release, :resolved, external_id: "lYBUbBu4W08") }
  let(:link) { "https://music.youtube.com/watch?v=lYBUbBu4W08&si=AbC" }
  let(:now) { Time.zone.local(2026, 10, 14, 12) }

  def find(reply_to_message, replied_at: now)
    described_class.find(chat: chat, reply_to_message: reply_to_message&.with_indifferent_access, replied_at: replied_at)
  end

  def person_message(message_id:, text: link)
    { message_id: message_id, from: { id: 555, is_bot: false }, text: text }
  end

  it "finds a share by the link message's number or the announcement's" do
    share = create(:release_share, chat: chat, release: release, telegram_message_id: 42, announcement_telegram_message_id: 43)

    expect(find(person_message(message_id: 42))).to eq(share)
    expect(find({ message_id: 43, from: { is_bot: true }, text: "🎵 Queen" })).to eq(share)
  end

  it "falls back to the link in the replied-to message, taking the latest share before the reply" do
    first = create(:release_share, chat: chat, release: release, telegram_message_id: 900_001, shared_at: now - 1.year)
    second = create(:release_share, chat: chat, release: release, telegram_message_id: 900_002, shared_at: now - 1.month)
    create(:release_share, chat: chat, release: release, shared_at: now + 1.hour) # after the reply

    expect(find(person_message(message_id: 14_210))).to eq(second)
    expect(find(person_message(message_id: 14_210), replied_at: now - 6.months)).to eq(first)
  end

  it "finds a link hidden behind words in the replied-to message" do
    share = create(:release_share, chat: chat, release: release, shared_at: now - 1.day)
    replied = person_message(message_id: 14_210, text: "оцініть").merge(entities: [ { type: "text_link", offset: 0, length: 7, url: link } ])

    expect(find(replied)).to eq(share)
  end

  it "doesn't fall back for a bot's message, a release never shared here, or no reply" do
    create(:release_share, chat: chat, release: release, shared_at: now - 1.day)
    create(:release_share, release: create(:release, :resolved, external_id: "aaaaaaaaaaa"), shared_at: now - 1.day) # another chat

    expect(find({ message_id: 14_210, from: { is_bot: true }, caption: "Source ✤ Via", text: link })).to be_nil
    expect(find(person_message(message_id: 14_211, text: "https://music.youtube.com/watch?v=aaaaaaaaaaa"))).to be_nil
    expect(find(person_message(message_id: 14_212, text: "без посилання"))).to be_nil
    expect(find(nil)).to be_nil
  end
end
