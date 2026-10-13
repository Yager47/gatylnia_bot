require "rails_helper"

RSpec.describe Camerton::StatsCommand do
  let(:chat) { create(:chat, camerton_enabled: true) }

  def command(text, reply_to_message: nil)
    described_class.new(command: text, chat: chat, reply_to_message: reply_to_message).call
  end

  it "answers топ and дно, with or without a period" do
    expect(command("топ")).to start_with("🏆 Топ за весь час:")
    expect(command("дно")).to start_with("🗑 Дно за весь час:")
    expect(command("топ за тиждень")).to start_with("🏆 Топ за поточний тиждень:")
    expect(command("дно за рік")).to start_with("🗑 Дно за поточний рік:")
  end

  it "uses the Kyiv calendar for periods" do
    release = create(:release, :resolved)
    create(:release_share, chat: chat, release: release, shared_at: Time.zone.local(2026, 10, 1, 0, 30))
    create_list(:review, 2, chat: chat, release: release, score: 8)

    travel_to Time.zone.local(2026, 10, 13, 12) do
      expect(command("топ за місяць")).to include("Bohemian Rhapsody")
    end
  end

  it "leaves unknown commands and periods to others" do
    expect(command("топ за вчора")).to be_nil
    expect(command("баланс")).to be_nil
  end

  it "answers nothing in a chat with Camerton off" do
    chat.update!(camerton_enabled: false)

    expect(command("топ")).to be_nil
  end

  describe "оцінки" do
    let!(:share) { create(:release_share, chat: chat, release: create(:release, :resolved), telegram_message_id: 42, announcement_telegram_message_id: 43) }

    it "shows the card of the release replied to, through the link or the announcement" do
      expect(command("оцінки", reply_to_message: { message_id: 42 })).to start_with("🎵 Queen — Bohemian Rhapsody · пісня")
      expect(command("оцінки", reply_to_message: { message_id: 43 })).to start_with("🎵 Queen — Bohemian Rhapsody · пісня")
    end

    it "explains how to use it when it isn't a reply to a release" do
      expect(command("оцінки")).to start_with("Відповідай цією командою")
      expect(command("оцінки", reply_to_message: { message_id: 999 })).to start_with("Відповідай цією командою")
    end
  end

  describe "through a chat" do
    def dispatch(update)
      TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
    end

    before do
      chat.update!(telegram_id: telegram_chat[:id].to_s, mode: :quiet)
      create(:release_share, chat: chat, release: create(:release, :resolved), telegram_message_id: 42)
    end

    it "answers оцінки replied to a release instead of storing it as feedback" do
      dispatch(message_update(text: "@test_bot оцінки", message_id: 100, reply_to_message: { message_id: 42 }))

      expect(fake_telegram.sent_messages.sole[:text]).to start_with("🎵 Queen — Bohemian Rhapsody · пісня")
      expect(Review.count).to eq(0)
    end

    it "answers топ in any mode" do
      chat.update!(mode: :accountant)

      dispatch(message_update(text: "@test_bot топ"))

      expect(fake_telegram.sent_messages.sole[:text]).to start_with("🏆 Топ за весь час:")
    end
  end
end
