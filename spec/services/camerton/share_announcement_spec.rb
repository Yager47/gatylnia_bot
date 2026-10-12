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

    it "says when the name wasn't found" do
      release = build(:release, :album, status: :unresolvable)

      expect(described_class.new(build(:release_share, release: release)).text)
        .to eq("💿 Альбом: назву на YouTube не знайшов, але відгуки приймаю.")
    end
  end

  describe "#deliver" do
    it "replies to the shared link and records the reply" do
      share = share_of(create(:release, :resolved))

      described_class.new(share).deliver

      sent = fake_telegram.sent_messages.sole
      expect(sent).to include(chat_id: chat.telegram_id, text: "🎵 Queen — Bohemian Rhapsody · пісня")
      expect(sent[:reply_parameters].to_h).to eq(message_id: 42, allow_sending_without_reply: true)
      expect(share.reload.announced_at).to be_present
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
