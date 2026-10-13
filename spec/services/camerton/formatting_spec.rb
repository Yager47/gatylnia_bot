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

  describe ".release" do
    it "shows the icon with the artist and title, the title alone, or the link" do
      expect(described_class.release(build(:release, :resolved))).to eq("🎵 Queen — Bohemian Rhapsody")
      expect(described_class.release(build(:release, :album, status: :resolved, artist: nil, title: "Revival"))).to eq("💿 Revival")
      expect(described_class.release(build(:release, external_id: "lYBUbBu4W08", url: "https://music.youtube.com/watch?v=lYBUbBu4W08")))
        .to eq("🎵 https://music.youtube.com/watch?v=lYBUbBu4W08")
    end
  end
end
