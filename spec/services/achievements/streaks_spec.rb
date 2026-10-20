require "rails_helper"

RSpec.describe Achievements::Streaks do
  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:olya) { create(:user, username: "olya", chats: [ chat ]) }

  # A scored review whose first message is at that Kyiv time.
  def review_at(time, user: olya)
    review = create(:review, chat: chat, user: user, release: create(:release, :resolved), score: 7)
    create(:review_message, review: review, sent_at: time)
    review
  end

  def review_on(day, user: olya)
    review_at(Time.zone.local(2026, 10, day, 12), user: user)
  end

  def run(day, hour = 20)
    described_class.new(chat, now: Time.zone.local(2026, 10, day, hour)).call
  end

  def sent_texts
    fake_telegram.sent_messages.map { |message| message[:text] }
  end

  it "awards it on the 3rd day in a row, once" do
    [ 17, 18 ].each { |day| review_on(day) }
    run(18)
    review_on(19)
    run(19)
    run(19, 21)

    expect(sent_texts).to eq([ "🏆 @olya отримує ачівку «Серія»: 3 дні поспіль з оцінками 🔥" ])
    expect(chat.achievements.sole).to have_attributes(code: "streak", period: "streak-2026-10-17", level: 3, finished_at: nil)
  end

  it "grows silently between milestones and announces 7, 10, 15" do
    (1..6).each { |day| review_on(day) }
    run(6)
    review_on(7)
    run(7)
    (8..11).each { |day| review_on(day) }
    run(11) # passed 10 on the way

    expect(sent_texts).to eq([
      "🏆 @olya отримує ачівку «Серія»: 6 днів поспіль з оцінками 🔥",
      "🔥 Серія @olya: 7 днів поспіль",
      "🔥 Серія @olya: 11 днів поспіль"
    ])
    expect(chat.achievements.sole.level).to eq(11)
  end

  it "stays alive through a day with no review yet, and ends the morning after a missed day" do
    (17..20).each { |day| review_on(day) }
    run(20)
    run(21, 9) # nothing yet on the 21st
    run(22, 9)
    run(23, 9)

    expect(sent_texts).to eq([
      "🏆 @olya отримує ачівку «Серія»: 4 дні поспіль з оцінками 🔥",
      "💔 Серія @olya закінчилась: 4 дні поспіль"
    ])
    expect(chat.achievements.sole.finished_at).to eq(Time.zone.local(2026, 10, 22, 9))
  end

  it "follows each member's run on its own, on the same days" do
    petro = create(:user, username: "petro", chats: [ chat ])
    [ 17, 18, 19 ].each { |day| [ olya, petro ].each { |user| review_on(day, user: user) } }

    run(19)

    expect(sent_texts.sole.lines(chomp: true)).to contain_exactly(
      "🏆 @olya отримує ачівку «Серія»: 3 дні поспіль з оцінками 🔥",
      "🏆 @petro отримує ачівку «Серія»: 3 дні поспіль з оцінками 🔥"
    )
  end

  it "counts days in Kyiv time" do
    review_at(Time.zone.local(2026, 10, 17, 23, 50))
    review_at(Time.zone.local(2026, 10, 18, 0, 10))
    review_at(Time.zone.local(2026, 10, 19, 23, 59))

    run(19, 23)

    expect(chat.achievements.sole.level).to eq(3)
  end

  it "takes it back, with an announcement, when removed reviews break the run" do
    reviews = [ 17, 18, 19 ].map { |day| review_on(day) }
    run(19)

    reviews[1].destroy!
    run(19, 21)

    expect(sent_texts.last).to eq("↩️ @olya втрачає ачівку «Серія»: оцінок поспіль уже менше 3")
    expect(chat.achievements.sole.revoked_at).to be_present
  end

  it "leaves alone runs that ended before it saw them, and other members' days" do
    (1..5).each { |day| review_on(day) }
    [ 18, 19 ].each { |day| review_on(day) }
    review_on(17, user: create(:user, chats: [ chat ]))

    run(19)

    expect(chat.achievements).to be_empty
    expect(sent_texts).to be_empty
  end

  it "doesn't count unscored replies" do
    [ 17, 18 ].each { |day| review_on(day) }
    review_on(19).update!(score: nil)

    run(19)

    expect(chat.achievements).to be_empty
  end
end
