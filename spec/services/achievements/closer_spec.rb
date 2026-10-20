require "rails_helper"

RSpec.describe Achievements::Closer do
  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:olya) { create(:user, username: "olya", chats: [ chat ]) }
  # Monday of 2026-W44, at the scheduled hour.
  let(:monday) { Time.zone.local(2026, 10, 26, 9) }

  def scored(user, at:, score: 9)
    release = create(:release, :resolved)
    review = create(:review, chat: chat, user: user, release: release, score: score)
    # Shared by the reviewer long before: no sharing or first-listener rule
    # has anything to say.
    share = create(:release_share, chat: chat, release: release, user: user, shared_at: at - 30.days)
    create(:review_message, review: review, release_share: share, sent_at: at)
  end

  it "decides the week that just ended under a header, once" do
    3.times { scored(olya, at: Time.zone.local(2026, 10, 25, 23, 30)) }
    scored(olya, at: monday - 1.hour, score: 2) # this week's, not last week's

    described_class.new(chat, :week, now: monday).call
    described_class.new(chat, :week, now: monday + 2.hours).call

    expect(fake_telegram.sent_messages.map { |message| message[:text] }).to eq([
      "🏁 Підсумки тижня:\n🏆 @olya отримує ачівку «Всеїдний»: від 3 оцінок за тиждень, і всі 8–10"
    ])
    expect(chat.achievements.sole).to have_attributes(code: "all_positive", period: "2026-W43", awarded_at: monday)
  end

  it "decides only the rules of that kind, and the instant checker never runs them" do
    3.times { scored(olya, at: Time.zone.local(2026, 10, 20)) }

    Achievements::Checker.new(chat, now: Time.zone.local(2026, 10, 21)).call
    described_class.new(chat, :month, now: Time.zone.local(2026, 11, 1, 9)).call

    expect(chat.achievements.pluck(:code, :period)).to eq([])
  end

  it "decides the releases that turned a week old, daily" do
    release = create(:release, :resolved)
    create(:release_share, chat: chat, release: release, user: olya, shared_at: Time.zone.local(2026, 10, 19, 20))
    [ 1, 9 ].each { |value| create(:review, chat: chat, release: release, score: value) }

    described_class.new(chat, :release, now: monday).call
    described_class.new(chat, :release, now: monday + 3.hours).call

    expect(fake_telegram.sent_messages.map { |message| message[:text] }).to eq([
      "🏁 Релізи тижневої давності:\n🏆 @olya отримує ачівку «Розкол» за 🎵 Queen — Bohemian Rhapsody: оцінки розійшлися на 6+ балів"
    ])
    expect(chat.achievements.sole).to have_attributes(code: "split", period: "release-#{release.id}")
  end
end
