require "rails_helper"

RSpec.describe Camerton::HistoryImport do
  # A bot's id is the number before the colon in its token; the fixture's
  # bot posts as author 42.
  around do |example|
    original = ENV["TELEGRAM_BOT_API_TOKEN"]
    ENV["TELEGRAM_BOT_API_TOKEN"] = "42:test-token"
    example.run
  ensure
    ENV["TELEGRAM_BOT_API_TOKEN"] = original
  end

  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:messages) { TelegramExport::HtmlParser.new(file_fixture("camerton_export")).each_message.to_a }
  let!(:ivan) { create(:user, telegram_id: "999", first_name: "Іван", last_name: "Без Фото", username: nil, chats: [ chat ]) }

  def import(dry_run: false, messages: self.messages)
    described_class.new(chat: chat, messages: messages, dry_run: dry_run).call
  end

  it "creates shares and text reviews from replies, silently" do
    report = import

    song, album = Release.order(:id).to_a
    expect(song).to have_attributes(external_id: "lYBUbBu4W08", kind: "song", status: "pending")
    expect(album).to have_attributes(external_id: "OLAK5uy_album0001", kind: "album")

    petro = User.find_by!(telegram_id: "555")
    olya = User.find_by!(telegram_id: "777")
    expect(chat.release_shares.order(:telegram_message_id).map { |s| [ s.telegram_message_id, s.release, s.user, s.shared_at ] }).to eq(
      [
        [ 500, song, petro, Time.zone.local(2026, 10, 1, 20, 0) ],
        [ 601, album, olya, Time.zone.local(2026, 10, 2, 10, 0) ]
      ]
    )
    expect(chat.users).to include(petro, olya)

    olya_review = Review.find_by!(chat: chat, release: song, user: olya)
    expect(olya_review.messages.order(:sent_at).pluck(:telegram_message_id, :text, :source))
      .to eq([ [ 501, "шедевр, 9/10", "text" ], [ 502, "хоча інтро задовге", "text" ] ])
    expect(Review.find_by!(chat: chat, release: song, user: ivan).messages.sole.text).to eq("ну таке, мід")
    expect(Review.count).to eq(2)

    expect(fake_telegram.calls).to be_empty
    expect(AnnounceReleaseJob).not_to have_been_enqueued
    [ song, album ].each { |release| expect(ResolveReleaseJob).to have_been_enqueued.with(release) }
    Review.find_each { |review| expect(ScoreReviewJob).to have_been_enqueued.with(review, react: false).once }

    expect(report).to have_attributes(
      shares_created: 2, shares_existing: 0, releases_created: 2, replies_created: 3, replies_updated: 0, reviews_to_score: 2
    )
    expect(report.skipped).to eq(not_text: 1, bot_messages: 1, bot_commands: 1)
  end

  it "ignores the given senders' shares and replies" do
    report = described_class.new(chat: chat, messages: messages, dry_run: false, ignored_sender_ids: [ 777 ]).call

    expect(chat.release_shares.pluck(:telegram_message_id)).to eq([ 500 ]) # Оля's album share is gone
    expect(User.where(telegram_id: "777")).to be_empty
    expect(Review.joins(:user).pluck("users.telegram_id")).to eq([ "999" ])
    expect(report.skipped).to include(ignored_senders: 3)
  end

  it "matches a sender without a userpic by name, and reports one it can't match" do
    ivan.update!(last_name: "Інший")

    report = import

    expect(Review.where(user: ivan)).to be_empty
    expect(report.skipped).to include("unknown_sender: Іван Без Фото": 1)
  end

  it "doesn't guess between two members with the same name" do
    create(:user, first_name: "Іван", last_name: "Без Фото", chats: [ chat ])

    report = import

    expect(Review.where(user: ivan)).to be_empty
    expect(report.skipped).to include("unknown_sender: Іван Без Фото": 1)
  end

  it "writes nothing and enqueues nothing on a dry run, but reports what it would do" do
    report = import(dry_run: true)

    expect([ Release.count, ReleaseShare.count, Review.count, ReviewMessage.count ]).to eq([ 0, 0, 0, 0 ])
    expect(User.where(telegram_id: %w[555 777])).to be_empty
    expect(ResolveReleaseJob).not_to have_been_enqueued
    expect(ScoreReviewJob).not_to have_been_enqueued
    expect(report).to have_attributes(shares_created: 2, replies_created: 3, reviews_to_score: 2)
  end

  it "rolls a dry run back even inside the caller's transaction" do
    ActiveRecord::Base.transaction(joinable: true) do
      import(dry_run: true)

      expect([ Release.count, ReleaseShare.count, Review.count ]).to eq([ 0, 0, 0 ])
    end
  end

  it "leaves nothing behind for the next run after a dry run on the same chat" do
    import(dry_run: true)
    report = import(dry_run: true)

    expect(report).to have_attributes(shares_created: 2, replies_created: 3, reviews_to_score: 2)
  end

  it "is safe to run again, updating only replies whose text changed" do
    import
    clear_enqueued_jobs
    edited = messages.map { |m| m.telegram_message_id == 502 ? m.with(text: "хоча інтро задовге, але ок") : m }

    report = import(messages: edited)

    expect([ ReleaseShare.count, Review.count, ReviewMessage.count ]).to eq([ 2, 2, 3 ])
    expect(ReviewMessage.find_by!(telegram_message_id: 502).text).to eq("хоча інтро задовге, але ок")
    expect(report).to have_attributes(shares_created: 0, shares_existing: 2, releases_created: 0, replies_created: 0, replies_updated: 1, reviews_to_score: 1)
    expect(ResolveReleaseJob).not_to have_been_enqueued
  end

  it "counts replies to a share or announcement already in the chat, and keeps known releases" do
    release = create(:release, :resolved, external_id: "lYBUbBu4W08")
    create(:release_share, chat: chat, release: release, telegram_message_id: 400, announcement_telegram_message_id: 401)
    reply = messages.find { |m| m.telegram_message_id == 501 }.with(telegram_message_id: 450, reply_to_message_id: 401)

    report = import(messages: messages + [ reply ])

    expect(ReviewMessage.find_by!(telegram_message_id: 450).release_share.telegram_message_id).to eq(400)
    expect(report.releases_created).to eq(1) # only the album
    expect(ResolveReleaseJob).not_to have_been_enqueued.with(release)
  end
end
