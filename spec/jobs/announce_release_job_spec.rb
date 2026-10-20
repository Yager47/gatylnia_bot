require "rails_helper"

RSpec.describe AnnounceReleaseJob do
  let(:share) { create(:release_share, release: create(:release)) }

  before { allow_any_instance_of(Camerton::Discogs).to receive(:search_masters).and_return([]) }

  it "looks the release up, then announces it" do
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata)
      .and_return(Camerton::SourceMetadata.new(title: "Never Gonna Give You Up", author: "Rick Astley - Topic"))
    allow_any_instance_of(Camerton::ReleaseNameCleaner).to receive(:call)
      .and_return(Camerton::ReleaseNameCleaner::Result.new(artist: "Rick Astley", title: "Never Gonna Give You Up"))

    described_class.perform_now(share)

    expect(share.release.reload).to be_resolved
    expect(fake_telegram.sent_messages.sole[:text]).to eq("🎵 Rick Astley — Never Gonna Give You Up · пісня")
    expect(CheckAchievementsJob).to have_been_enqueued.with(share.chat)
  end

  it "announces a duplicate link as the release it was merged into, with its history" do
    earlier = create(:release, :resolved, artist: "Rick Astley", title: "Never Gonna Give You Up")
    create(:release_share, chat: share.chat, release: earlier, shared_at: Time.zone.local(2026, 3, 12))
    allow(Camerton::Platforms::YoutubeMusic).to receive(:source_metadata)
      .and_return(Camerton::SourceMetadata.new(title: "Never Gonna Give You Up (Lyrics)", author: "Lyrics Channel"))
    allow_any_instance_of(Camerton::ReleaseNameCleaner).to receive(:call)
      .and_return(Camerton::ReleaseNameCleaner::Result.new(artist: "Rick Astley", title: "Never Gonna Give You Up"))

    described_class.perform_now(share)

    expect(share.reload.release).to eq(earlier)
    expect(fake_telegram.sent_messages.sole[:text]).to include("вже скидали 12.03")
  end

  it "adds Discogs' album, year and styles to the announcement" do
    share.release.update!(status: :resolved, artist: "Queen", title: "Bohemian Rhapsody")
    allow_any_instance_of(Camerton::Discogs).to receive_messages(
      search_masters: [ { "id" => 7, "year" => "1975", "format" => [ "Vinyl", "LP", "Album" ] } ],
      master: { "id" => 7, "title" => "A Night At The Opera", "year" => 1975, "genres" => [ "Rock" ], "styles" => [ "Hard Rock", "Art Rock", "Prog Rock" ] }
    )

    described_class.perform_now(share)

    expect(fake_telegram.sent_messages.sole[:text])
      .to eq("🎵 Queen — Bohemian Rhapsody · пісня · A Night At The Opera, 1975 · Hard Rock, Art Rock")
  end

  it "announces without Discogs details when Discogs fails" do
    share.release.update!(status: :resolved, artist: "Queen", title: "Bohemian Rhapsody")
    allow_any_instance_of(Camerton::Discogs).to receive(:search_masters).and_raise(Camerton::Discogs::TransientError, "Discogs answered 503")

    described_class.perform_now(share)

    expect(fake_telegram.sent_messages.sole[:text]).to eq("🎵 Queen — Bohemian Rhapsody · пісня")
    expect(described_class).not_to have_been_enqueued
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
