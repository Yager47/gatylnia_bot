require "rails_helper"

RSpec.describe Camerton::Formatting do
  describe ".score" do
    it "rounds to one decimal and drops a trailing .0" do
      expect([ 7.5, 8.0, BigDecimal("7.3333"), 10 ].map { |value| described_class.score(value) }).to eq(%w[7.5 8 7.3 10])
    end
  end

  describe ".release_link" do
    let(:share) { build(:release_share, release: build(:release, :resolved, artist: "Tom & <Jerry>"), telegram_message_id: 42) }

    it "links an escaped name to the shared message in a supergroup" do
      chat = build(:chat, telegram_id: "-1001234567890")

      expect(described_class.release_link(share, chat))
        .to eq(%(<a href="https://t.me/c/1234567890/42">🎵 Tom &amp; &lt;Jerry&gt; — Bohemian Rhapsody</a>))
    end

    it "links only shares posted after a basic group became the supergroup to the message, older ones to YouTube Music" do
      chat = build(:chat, telegram_id: "-1001234567890", supergroup_since: Time.zone.parse("2026-10-14 16:00"))

      share.shared_at = Time.zone.parse("2026-10-14 15:59")
      expect(described_class.release_link(share, chat))
        .to eq(%(<a href="#{share.release.url}">🎵 Tom &amp; &lt;Jerry&gt; — Bohemian Rhapsody</a>))

      share.shared_at = Time.zone.parse("2026-10-14 16:00")
      expect(described_class.release_link(share, chat)).to start_with(%(<a href="https://t.me/c/1234567890/42">))
    end

    it "links to YouTube Music in a basic group, which has no t.me/c links" do
      chat = build(:chat, telegram_id: "-123456", telegram_type: "group")

      expect(described_class.release_link(share, chat))
        .to eq(%(<a href="#{share.release.url}">🎵 Tom &amp; &lt;Jerry&gt; — Bohemian Rhapsody</a>))
    end

    it "escapes the platform link" do
      chat = build(:chat, telegram_id: "-123456", telegram_type: "group")
      share.release.url = "https://music.youtube.com/watch?v=a&list=b"

      expect(described_class.release_link(share, chat)).to start_with(%(<a href="https://music.youtube.com/watch?v=a&amp;list=b">))
    end
  end

  describe ".release" do
    it "shows the icon with the artist and title, the title alone, or the link" do
      expect(described_class.release(build(:release, :resolved))).to eq("🎵 Queen — Bohemian Rhapsody")
      expect(described_class.release(build(:release, :album, status: :resolved, artist: nil, title: "Revival"))).to eq("💿 Revival")
      expect(described_class.release(build(:release, external_id: "lYBUbBu4W08", url: "https://music.youtube.com/watch?v=lYBUbBu4W08")))
        .to eq("🎵 https://music.youtube.com/watch?v=lYBUbBu4W08")
    end
  end
end
