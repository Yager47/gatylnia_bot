require "rails_helper"

RSpec.describe Camerton::Formatting do
  describe ".count" do
    it "uses the Ukrainian plural forms" do
      forms = [ 1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111 ].to_h do |number|
        [ number, described_class.count(number, "оцінка", "оцінки", "оцінок") ]
      end

      expect(forms).to eq(
        1 => "1 оцінка", 2 => "2 оцінки", 4 => "4 оцінки", 5 => "5 оцінок", 11 => "11 оцінок", 12 => "12 оцінок",
        14 => "14 оцінок", 21 => "21 оцінка", 22 => "22 оцінки", 25 => "25 оцінок", 101 => "101 оцінка", 111 => "111 оцінок"
      )
    end
  end

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

    it "leaves just the escaped name in a basic group, which has no t.me/c links" do
      chat = build(:chat, telegram_id: "-123456", telegram_type: "group")

      expect(described_class.release_link(share, chat)).to eq("🎵 Tom &amp; &lt;Jerry&gt; — Bohemian Rhapsody")
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
