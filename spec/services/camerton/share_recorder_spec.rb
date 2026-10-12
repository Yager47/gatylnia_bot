require "rails_helper"

RSpec.describe Camerton::ShareRecorder do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
  end

  let(:song_url) { "https://music.youtube.com/watch?v=lYBUbBu4W08&si=AbC123" }
  let!(:chat) { create(:chat, telegram_id: telegram_chat[:id].to_s, mode: :quiet, camerton_enabled: true) }

  it "records a shared link as a pending release and announces it in the background" do
    sent_at = Time.zone.local(2026, 10, 13, 12, 0)

    dispatch(message_update(text: "заціни #{song_url}", message_id: 42, date: sent_at.to_i))

    release = Release.sole
    expect(release).to have_attributes(
      platform: "youtube_music", external_id: "lYBUbBu4W08", kind: "song", status: "pending",
      url: "https://music.youtube.com/watch?v=lYBUbBu4W08"
    )
    share = ReleaseShare.sole
    expect(share).to have_attributes(
      chat: chat, release: release, user: User.find_by!(telegram_id: "555"), telegram_message_id: 42, shared_at: sent_at
    )
    expect(AnnounceReleaseJob).to have_been_enqueued.with(share)
  end

  it "still lets the mode handler record the message" do
    dispatch(message_update(text: song_url))

    expect(Message.sole.content).to eq(song_url)
  end

  it "records a second share of a known release against the same release" do
    release = create(:release, :resolved, external_id: "lYBUbBu4W08")

    dispatch(message_update(text: song_url, message_id: 43))

    expect(Release.sole).to eq(release)
    expect(ReleaseShare.sole).to have_attributes(release: release, telegram_message_id: 43)
    expect(AnnounceReleaseJob).to have_been_enqueued.with(ReleaseShare.sole)
  end

  it "is safe to run twice for the same message" do
    payload = message_update(text: song_url, message_id: 42)

    2.times { dispatch(payload) }

    expect([ Release.count, ReleaseShare.count ]).to eq([ 1, 1 ])
  end

  it "doesn't announce a share again when the update is reprocessed after its announcement" do
    payload = message_update(text: song_url, message_id: 42)
    dispatch(payload)
    ReleaseShare.sole.update!(announced_at: Time.current)
    clear_enqueued_jobs

    dispatch(payload)

    expect(AnnounceReleaseJob).not_to have_been_enqueued
  end

  it "ignores edits" do
    dispatch(edited_message_update(text: song_url))

    expect(ReleaseShare.count).to eq(0)
  end

  it "does nothing in a chat with Camerton off" do
    chat.update!(camerton_enabled: false)

    dispatch(message_update(text: song_url))

    expect([ Release.count, ReleaseShare.count ]).to eq([ 0, 0 ])
    expect(AnnounceReleaseJob).not_to have_been_enqueued
  end
end
