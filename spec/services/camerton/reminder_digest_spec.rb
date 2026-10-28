require "rails_helper"

RSpec.describe Camerton::ReminderDigest do
  let(:chat) { create(:chat, telegram_id: "-1001234567890", camerton_enabled: true) }
  let(:now) { Time.zone.local(2026, 10, 13, 20, 0) }

  def member(name, username: name.downcase)
    create(:user, first_name: name, last_name: nil, username: username, chats: [ chat ])
  end

  def shared(title, by:, at: now - 1.day, message_id: nil, kind: :song)
    release = create(:release, kind == :album ? :album : :resolved, status: :resolved, artist: "Artist", title: title)
    create(:release_share, chat: chat, release: release, user: by, shared_at: at, telegram_message_id: message_id || rand(1_000..9_999))
    release
  end

  def digest
    described_class.new(chat, now: now).text
  end

  describe "#text" do
    it "lists each member's unscored releases from the last week, newest first, with links" do
      petro = member("Petro")
      olya = member("Olya")
      a = shared("A", by: petro, at: now - 3.days, message_id: 41)
      shared("B", by: olya, at: now - 1.day, message_id: 42, kind: :album)
      create(:review, chat: chat, release: a, user: olya, score: nil) # replied, but not a review

      expect(digest).to eq(<<~HTML.strip)
        🎧 Хто ще не оцінив свіже:

        @petro
        <a href="https://t.me/c/1234567890/42">💿 Artist — B</a>

        @olya
        <a href="https://t.me/c/1234567890/41">🎵 Artist — A</a>

        Відповідайте на реліз текстом, голосовим чи кружечком.
      HTML
    end

    it "skips members who scored it, releases older than a week, and other chats" do
      petro = member("Petro")
      olya = member("Olya")
      fresh = shared("Fresh", by: petro)
      shared("Old", by: petro, at: now - 8.days)
      create(:review, chat: chat, release: fresh, user: olya, score: 7)
      create(:release_share, release: create(:release, :resolved), shared_at: now - 1.day) # another chat

      expect(digest).to be_nil
    end

    it "counts the latest share, so a re-share restarts the week, and never reminds anyone who shared it" do
      petro = member("Petro")
      olya = member("Olya")
      member("Ivan")
      release = shared("Again", by: petro, at: now - 20.days, message_id: 10)
      create(:release_share, chat: chat, release: release, user: olya, shared_at: now - 2.days, telegram_message_id: 11)

      expect(digest).to include(%(@ivan\n<a href="https://t.me/c/1234567890/11">🎵 Artist — Again</a>))
      expect(digest).not_to include("@petro", "@olya")
    end

    it "lists releases only imported and scored in the last week, by when they were scored, to the platform" do
      petro = member("Petro")
      olya = member("Olya")
      album = create(:release, :album, status: :resolved, artist: "Artist", title: "Imported")
      create(:review, chat: chat, release: album, user: petro, score: 8, scored_at: now - 1.day, source: :spreadsheet)
      old = create(:release, :resolved, artist: "Artist", title: "Old import")
      create(:review, chat: chat, release: old, user: petro, score: 8, scored_at: now - 8.days, source: :spreadsheet)
      shared("Shared", by: petro, at: now - 2.days, message_id: 41)
      shared("Newer", by: petro, at: now - 1.hour, message_id: 42)

      expect(digest).to eq(<<~HTML.strip)
        🎧 Хто ще не оцінив свіже:

        @olya
        <a href="https://t.me/c/1234567890/42">🎵 Artist — Newer</a>
        <a href="#{album.url}">💿 Artist — Imported</a>
        <a href="https://t.me/c/1234567890/41">🎵 Artist — Shared</a>

        Відповідайте на реліз текстом, голосовим чи кружечком.
      HTML

      create(:review, chat: chat, release: album, user: olya, score: 3, scored_at: now - 1.hour, source: :spreadsheet)
      expect(digest).not_to include("Imported")
    end

    it "mentions a member without a username with a link, escaping names and titles" do
      sharer = member("Sharer")
      member("<Іван & Co>", username: nil).update!(telegram_id: "777")
      shared("Rock & <Roll>", by: sharer)

      expect(digest).to include(%(<a href="tg://user?id=777">&lt;Іван &amp; Co&gt;</a>\n<a href="https://t.me/c/1234567890/))
      expect(digest).to include("🎵 Artist — Rock &amp; &lt;Roll&gt;</a>")
    end

    it "shows five releases per member and how many more" do
      sharer = member("Sharer")
      member("Olya")
      7.times { |index| shared("R#{index}", by: sharer, at: now - index.hours) }

      block = digest.split("\n\n").find { |b| b.start_with?("@olya") }
      expect(block.lines.map(&:strip)).to match([ "@olya", *Array.new(5, /\A<a href=.*R\d<\/a>\z/), "і ще 2" ])
    end

    it "links releases to YouTube Music in a basic group, which has no t.me/c links" do
      chat.update!(telegram_id: "-123456", telegram_type: "group")
      sharer = member("Sharer")
      member("Olya")
      shared("A", by: sharer)

      expect(digest).to match(%r{@olya\n<a href="https://music\.youtube\.com/watch\?v=vid\d+">🎵 Artist — A</a>})
      expect(digest).not_to include("t.me")
    end

    it "runs the same number of queries however many members and releases there are" do
      sharer = member("Sharer")
      member("Olya")
      shared("A", by: sharer)
      create(:review, chat: chat, release: create(:release, :resolved), user: sharer, score: 7, scored_at: now - 1.hour)
      queries_for_few = count_queries { digest }

      3.times { |index| member("M#{index}") }
      3.times { |index| shared("More #{index}", by: sharer) }
      3.times { |index| create(:review, chat: chat, release: create(:release, :resolved), user: sharer, score: 7, scored_at: now - index.hours) }
      chat.reload # drops the cached pseudonyms (Chat#member_names), as a new update would

      expect(count_queries { digest }).to eq(queries_for_few).and eq(8)
    end
  end

  describe "#deliver" do
    before do
      sharer = member("Sharer")
      member("Olya")
      shared("A", by: sharer)
    end

    it "sends the digest as HTML and records it" do
      described_class.new(chat, now: now).deliver

      sent = fake_telegram.sent_messages.sole
      expect(sent).to include(chat_id: chat.telegram_id, parse_mode: "HTML")
      expect(sent[:link_preview_options].to_h).to eq(is_disabled: true)
      expect(sent[:text]).to start_with("🎧 Хто ще не оцінив свіже:")
      expect(chat.messages.sole).to have_attributes(role: "assistant", content: sent[:text])
      expect(chat.reload.camerton_digest_sent_on).to eq(Date.new(2026, 10, 13))
    end

    it "sends once a day" do
      2.times { described_class.new(chat, now: now).deliver }
      described_class.new(chat, now: now + 1.day).deliver

      expect(fake_telegram.sent_messages.size).to eq(2)
    end

    it "sends nothing when nobody has anything to score, but marks the day" do
      Review.create!(chat: chat, release: Release.sole, user: User.find_by!(username: "olya"), score: 8)

      described_class.new(chat, now: now).deliver

      expect(fake_telegram.sent_messages).to be_empty
      expect(chat.reload.camerton_digest_sent_on).to eq(Date.new(2026, 10, 13))
    end

    it "sends nothing once Camerton is off" do
      chat.update!(camerton_enabled: false)

      described_class.new(chat, now: now).deliver

      expect(fake_telegram.sent_messages).to be_empty
    end

    it "keeps the day open and records nothing when sending fails, so a retry sends it" do
      allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "Telegram unreachable")

      expect { described_class.new(chat, now: now).deliver }.to raise_error(Faraday::ConnectionFailed)

      expect(chat.reload.camerton_digest_sent_on).to be_nil
      expect(chat.messages.count).to eq(0)
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
