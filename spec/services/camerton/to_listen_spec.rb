require "rails_helper"

RSpec.describe Camerton::ToListen do
  let(:chat) { create(:chat, telegram_id: "-1001234567890", camerton_enabled: true) }
  let(:olya) { create(:user, first_name: "Olya", last_name: nil, username: "olya", chats: [ chat ]) }
  let(:sharer) { create(:user, chats: [ chat ]) }

  def shared(title, at:, kind: :resolved, by: sharer, genres: nil, styles: nil, **share)
    release = create(:release, kind, status: :resolved, artist: "Artist", title: title, genres: genres, styles: styles)
    create(:release_share, chat: chat, release: release, user: by, shared_at: at, **share)
    release
  end

  def to_listen(user = olya, **filters)
    described_class.new(chat: chat, user: user, **filters).text
  end

  # The release lines without their links.
  def names(**filters)
    to_listen(**filters).lines.map { |line| line.strip.gsub(/<[^>]+>/, "") }[2..]
  end

  it "lists unscored releases of any age, newest first, each linking to its share" do
    scored = shared("Scored", at: 1.hour.ago)
    create(:review, chat: chat, release: scored, user: olya, score: 6)
    replied = shared("Replied", at: 2.hours.ago)
    create(:review, chat: chat, release: replied, user: olya, score: nil) # not a review
    shared("Album", at: 1.day.ago, kind: :album, telegram_message_id: 42)
    shared("Old", at: 1.year.ago, telegram_message_id: 7)

    expect(to_listen).to eq(<<~TEXT.strip)
      🎧 Що ще послухати — Olya:

      <a href="https://t.me/c/1234567890/#{ReleaseShare.find_by(release: replied).telegram_message_id}">🎵 Artist — Replied</a>
      <a href="https://t.me/c/1234567890/42">💿 Artist — Album</a>
      <a href="https://t.me/c/1234567890/7">🎵 Artist — Old</a>
    TEXT
  end

  it "escapes the member's name" do
    olya.update!(first_name: "<Olya & Co>")

    expect(to_listen).to eq("🎧 &lt;Olya &amp; Co&gt;: усе вже оцінено.")
  end

  it "shows the 10 latest and how many more" do
    12.times { |index| shared("R#{index}", at: index.days.ago) }

    expect(names).to eq([ *(0..9).map { |index| "🎵 Artist — R#{index}" }, "і ще 2" ])
  end

  it "orders a re-shared release by its latest share, once, and links to that share" do
    old = shared("Old", at: 1.year.ago, telegram_message_id: 7)
    shared("Middle", at: 1.month.ago)
    create(:release_share, chat: chat, release: old, user: sharer, shared_at: 1.day.ago, telegram_message_id: 99)

    expect(names).to eq([ "🎵 Artist — Old", "🎵 Artist — Middle" ])
    expect(to_listen).to include(%(<a href="https://t.me/c/1234567890/99">🎵 Artist — Old</a>))
  end

  it "leaves out releases the member shared, even when someone else re-shared them, and other chats" do
    mine = shared("Mine", at: 1.month.ago, by: olya)
    create(:release_share, chat: chat, release: mine, user: sharer, shared_at: 1.day.ago)
    create(:release_share, release: create(:release, :resolved), shared_at: 1.day.ago) # another chat

    expect(to_listen).to eq("🎧 Olya: усе вже оцінено.")
  end

  describe "filters" do
    before do
      shared("Rock song", at: 1.hour.ago, genres: [ "Rock" ], styles: [ "Post-Punk" ])
      shared("Rock album", at: 2.hours.ago, kind: :album, genres: [ "Rock" ])
      shared("Jazz album", at: 3.hours.ago, kind: :album, genres: [ "Jazz" ])
      shared("Unknown album", at: 4.hours.ago, kind: :album)
    end

    it "lists only albums or songs, naming the filter" do
      expect(to_listen(kind: "album").lines.first.strip).to eq("🎧 Що ще послухати — Olya (альбоми):")
      expect(names(kind: "album")).to eq([ "💿 Artist — Rock album", "💿 Artist — Jazz album", "💿 Artist — Unknown album" ])
      expect(names(kind: "song")).to eq([ "🎵 Artist — Rock song" ])
    end

    it "lists only a genre or style, alone or with a kind" do
      expect(to_listen(genre: "rock").lines.first.strip).to eq("🎧 Що ще послухати — Olya (rock):")
      expect(names(genre: "rock")).to eq([ "🎵 Artist — Rock song", "💿 Artist — Rock album" ])
      expect(names(genre: "post-punk")).to eq([ "🎵 Artist — Rock song" ])
      expect(to_listen(kind: "album", genre: "rock").lines.first.strip).to eq("🎧 Що ще послухати — Olya (альбоми, rock):")
      expect(names(kind: "album", genre: "rock")).to eq([ "💿 Artist — Rock album" ])
    end

    it "counts the rest within the filter" do
      11.times { |index| shared("More jazz #{index}", at: 1.day.ago, kind: :album, genres: [ "Jazz" ]) }

      expect(names(genre: "jazz").last).to eq("і ще 2")
    end

    it "tells all scored apart from a genre nobody shared, escaping it" do
      create(:review, chat: chat, release: Release.find_by!(title: "Jazz album"), user: olya, score: 7)

      expect(to_listen(genre: "jazz")).to eq("🎧 Olya (jazz): усе вже оцінено.")
      expect(to_listen(kind: "song", genre: "jazz")).to eq("🎧 Не знайшов у чаті пісень з жанром «jazz».")
      expect(to_listen(genre: "<b>polka</b>")).to eq("🎧 Не знайшов у чаті релізів з жанром «&lt;b&gt;polka&lt;/b&gt;».")
    end
  end

  it "runs the same number of queries however many releases there are" do
    olya
    shared("A", at: 1.day.ago)
    queries_for_few = count_queries { to_listen }

    12.times { |index| shared("More #{index}", at: index.hours.ago) }
    chat.reload # drops the cached pseudonyms (Chat#member_names), as a new update would

    expect(count_queries { to_listen }).to eq(queries_for_few).and eq(4)
    chat.reload
    expect(count_queries { to_listen(kind: "song") }).to eq(4)
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
