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

  it "answers топ and дно for albums or songs, with or without a period" do
    expect(command("топ альбоми")).to start_with("🏆 Топ альбомів за весь час:")
    expect(command("дно пісні за місяць")).to start_with("🗑 Дно пісень за поточний місяць:")
    expect(command("топ за рік альбоми")).to be_nil
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

  describe "що послухати" do
    let(:me) { create(:user, first_name: "Me", last_name: nil, chats: [ chat ]) }
    let(:olya) { create(:user, first_name: "Olya", last_name: nil, username: "Olya", chats: [ chat ]) }

    before { create(:release_share, chat: chat, release: create(:release, :resolved), shared_at: 1.hour.ago) }

    def ask(text)
      described_class.new(command: text, chat: chat, user: me).call
    end

    it "lists the asker's releases to score, or another member's by @username, as HTML" do
      olya
      expect(ask("що послухати")).to be_a(Response::Html).and have_attributes(text: start_with("🎧 Що ще послухати — Me:"))
      expect(ask("що послухати @olya").text).to start_with("🎧 Що ще послухати — Olya:")
    end

    it "takes \"шо послухати\" as well" do
      olya
      expect(ask("шо послухати пісні @olya").text).to start_with("🎧 Що ще послухати — Olya (пісні):")
    end

    it "passes albums or songs, a genre and a @username through, in that order" do
      olya
      expect(ask("що послухати альбоми").text).to start_with("🎧 Me (альбоми): усе вже оцінено.")
      expect(ask("що послухати пісні").text).to start_with("🎧 Що ще послухати — Me (пісні):")
      expect(ask("що послухати hip hop").text).to eq("🎧 Не знайшов у чаті релізів з жанром «hip hop».")
      expect(ask("що послухати альбоми jazz @olya").text).to eq("🎧 Не знайшов у чаті альбомів з жанром «jazz».")
      expect(ask("що послухати пісні rock @olya").text).to start_with("🎧 Не знайшов у чаті пісень з жанром «rock».")
    end

    it "leaves a genre with an @ in the middle to others" do
      expect(ask("що послухати rock @olya ще щось")).to be_nil
    end

    it "says when the username isn't in the chat" do
      expect(ask("що послухати @nobody")).to eq("Не знайшов @nobody у цьому чаті.")
    end
  end

  describe "оцінки" do
    let!(:share) { create(:release_share, chat: chat, release: create(:release, :resolved), telegram_message_id: 42, announcement_telegram_message_id: 43) }

    it "shows the card of the release replied to, through the link or the announcement" do
      expect(command("оцінки", reply_to_message: { message_id: 42 })).to start_with("🎵 Queen — Bohemian Rhapsody · пісня")
      expect(command("оцінки", reply_to_message: { message_id: 43 })).to start_with("🎵 Queen — Bohemian Rhapsody · пісня")
    end

    it "shows the card when replied to an older link the bot knows only from an import" do
      old_link = { message_id: 14_210, from: { id: 555, is_bot: false }, text: share.release.url }

      expect(command("оцінки", reply_to_message: old_link.with_indifferent_access)).to start_with("🎵 Queen — Bohemian Rhapsody · пісня")
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
