require "rails_helper"

RSpec.describe Camerton::ShareAnnouncement do
  let(:chat) { create(:chat) }

  def share_of(release)
    create(:release_share, chat: chat, release: release, telegram_message_id: 42)
  end

  describe "#text" do
    it "names a song" do
      release = build(:release, :resolved, artist: "Queen", title: "Bohemian Rhapsody")

      expect(described_class.new(build(:release_share, release: release)).text).to eq("🎵 Queen — Bohemian Rhapsody · пісня")
    end

    it "names an album" do
      release = build(:release, :album, status: :resolved, artist: "Eminem", title: "Revival")

      expect(described_class.new(build(:release_share, release: release)).text).to eq("💿 Eminem — Revival · альбом")
    end

    it "leaves out a missing artist" do
      release = build(:release, :resolved, artist: nil, title: "Щось без автора")

      expect(described_class.new(build(:release_share, release: release)).text).to eq("🎵 Щось без автора · пісня")
    end

    it "adds a song's album and year, then two styles" do
      release = build(:release, :resolved, album_title: "A Night At The Opera", year: 1975, genres: [ "Rock" ], styles: [ "Hard Rock", "Art Rock", "Prog Rock" ])

      expect(described_class.new(build(:release_share, release: release)).text)
        .to eq("🎵 Queen — Bohemian Rhapsody · пісня · A Night At The Opera, 1975 · Hard Rock, Art Rock")
    end

    it "adds an album's year, and genres when there are no styles" do
      release = build(:release, :album, status: :resolved, artist: "Althea & Donna", title: "Uptown Top Ranking", year: 1978, genres: [ "Reggae" ], styles: [])

      expect(described_class.new(build(:release_share, release: release)).text)
        .to eq("💿 Althea & Donna — Uptown Top Ranking · альбом · 1978 · Reggae")
    end

    it "adds just the year when Discogs knows nothing else" do
      release = build(:release, :resolved, year: 1975)

      expect(described_class.new(build(:release_share, release: release)).text).to eq("🎵 Queen — Bohemian Rhapsody · пісня · 1975")
    end

    it "says when the name wasn't found" do
      release = build(:release, :album, status: :unresolvable)

      expect(described_class.new(build(:release_share, release: release)).text)
        .to eq("💿 Альбом: назву на YouTube не знайшов, але відгуки приймаю.")
    end
  end

  describe "#text for a re-share" do
    let(:release) { create(:release, :resolved) }
    let(:sharer) { create(:user) }

    around { |example| travel_to(Time.zone.local(2026, 10, 13, 12)) { example.run } }

    before { create(:release_share, chat: chat, release: release, user: sharer, shared_at: Time.zone.local(2026, 3, 12, 20)) }

    def reshare_text(shared_at: Time.current)
      described_class.new(create(:release_share, chat: chat, release: release, shared_at: shared_at)).text
    end

    it "adds the first share date and the average score, the sharer's own review included" do
      create(:review, chat: chat, release: release, score: 6)
      create(:review, chat: chat, release: release, score: 8)
      create(:review, chat: chat, release: release, score: nil)
      create(:review, chat: chat, release: release, user: sharer, score: 10)
      create(:review, release: release, score: 1) # another chat

      expect(reshare_text).to eq("🎵 Queen — Bohemian Rhapsody · пісня · вже скидали 12.03, середня 8")
    end

    it "rounds the average to one decimal" do
      create(:review, chat: chat, release: release, score: 7)
      create(:review, chat: chat, release: release, score: 7)
      create(:review, chat: chat, release: release, score: 8)

      expect(reshare_text).to end_with("середня 7.3")
    end

    it "says when nobody has scored it yet" do
      expect(reshare_text).to end_with("вже скидали 12.03, оцінок ще нема")
    end

    it "adds the year when the first share was in another year" do
      expect(reshare_text(shared_at: Time.zone.local(2027, 1, 5))).to include("вже скидали 12.03.2026")
    end

    it "doesn't count shares in other chats" do
      expect(described_class.new(create(:release_share, release: release)).text).to eq("🎵 Queen — Bohemian Rhapsody · пісня")
    end
  end

  describe "#deliver" do
    it "replies to the shared link and records the reply" do
      share = share_of(create(:release, :resolved))

      described_class.new(share).deliver

      sent = fake_telegram.sent_messages.sole
      expect(sent).to include(chat_id: chat.telegram_id, text: "🎵 Queen — Bohemian Rhapsody · пісня")
      expect(sent[:reply_parameters].to_h).to eq(message_id: 42, allow_sending_without_reply: true)
      expect(share.reload).to have_attributes(announced_at: be_present, announcement_telegram_message_id: 1001)
      expect(chat.messages.sole).to have_attributes(role: "assistant", content: sent[:text], telegram_message_id: 1001)
    end

    it "replies only once" do
      share = share_of(create(:release, :resolved))

      2.times { described_class.new(share).deliver }

      expect(fake_telegram.sent_messages.size).to eq(1)
    end

    it "waits until the release has been looked up" do
      share = share_of(create(:release))

      described_class.new(share).deliver

      expect(fake_telegram.sent_messages).to be_empty
      expect(share.reload.announced_at).to be_nil
    end

    it "leaves the share unannounced and records nothing when sending fails" do
      share = share_of(create(:release, :resolved))
      allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "Telegram unreachable")

      expect { described_class.new(share).deliver }.to raise_error(Faraday::ConnectionFailed)

      expect(share.reload.announced_at).to be_nil
      expect(chat.messages.count).to eq(0)
    end
  end
end
