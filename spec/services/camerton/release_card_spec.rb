require "rails_helper"

RSpec.describe Camerton::ReleaseCard do
  let(:chat) { create(:chat) }
  let(:release) { create(:release, :resolved) }
  let(:petro) { create(:user, first_name: "Петро", last_name: nil) }
  let!(:first_share) { create(:release_share, chat: chat, release: release, user: petro, shared_at: Time.zone.local(2026, 3, 12, 20)) }

  def review(name, score, summary: nil)
    user = create(:user, first_name: name, last_name: nil)
    create(:review, chat: chat, release: release, user: user, score: score, summary: summary, scored_at: Time.current)
  end

  it "shows the average, who shared it first, and every score best first" do
    review("Оля", 6, summary: "каже, що норм, але задовге")
    review("Іван", 9, summary: "каже, що це шедевр")
    review("Марко", 2)
    review("Тихий", nil)
    reshare = create(:release_share, chat: chat, release: release)

    expect(described_class.new(reshare).text).to eq(<<~TEXT.strip)
      🎵 Queen — Bohemian Rhapsody · пісня
      Середня 5.7 · 3 оцінки
      Вперше скинув Петро 12.03.2026, всього 2 рази

      Іван: 9 🔥 — каже, що це шедевр
      Оля: 6 👍 — каже, що норм, але задовге
      Марко: 2 🤬
    TEXT
  end

  it "says when nobody has scored it yet" do
    expect(described_class.new(first_share).text).to eq(<<~TEXT.strip)
      🎵 Queen — Bohemian Rhapsody · пісня
      Оцінок ще нема.
      Вперше скинув Петро 12.03.2026
    TEXT
  end

  it "only counts this chat" do
    create(:review, release: release, score: 10)

    expect(described_class.new(first_share).text).to include("Оцінок ще нема.")
  end
end
