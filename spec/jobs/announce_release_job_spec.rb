require "rails_helper"

RSpec.describe AnnounceReleaseJob do
  let(:share) { create(:release_share, release: create(:release)) }

  it "looks the release up, then announces it" do
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata)
      .and_return(Camerton::SourceMetadata.new(title: "Never Gonna Give You Up", author: "Rick Astley - Topic"))
    allow_any_instance_of(Camerton::ReleaseNameCleaner).to receive(:call)
      .and_return(Camerton::ReleaseNameCleaner::Result.new(artist: "Rick Astley", title: "Never Gonna Give You Up"))

    described_class.perform_now(share)

    expect(share.release.reload).to be_resolved
    expect(fake_telegram.sent_messages.sole[:text]).to eq("🎵 Rick Astley — Never Gonna Give You Up · пісня")
  end

  it "retries without announcing when YouTube is temporarily unavailable" do
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata)
      .and_raise(Camerton::YoutubeOembed::TransientError, "YouTube oEmbed answered 503")

    described_class.perform_now(share)

    expect(share.release.reload).to be_pending
    expect(fake_telegram.sent_messages).to be_empty
    expect(described_class).to have_been_enqueued.with(share)
  end

  it "retries when Telegram is unreachable, keeping the looked-up names" do
    share.release.update!(status: :resolved, artist: "Queen", title: "Bohemian Rhapsody")
    allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "Telegram unreachable")

    described_class.perform_now(share)

    expect(share.reload.announced_at).to be_nil
    expect(described_class).to have_been_enqueued.with(share)
  end
end
