require "rails_helper"

RSpec.describe Camerton::ReviewRecorder do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
  end

  let!(:chat) { create(:chat, telegram_id: telegram_chat[:id].to_s, mode: :quiet, camerton_enabled: true) }
  let(:release) { create(:release, :resolved) }
  let!(:share) { create(:release_share, chat: chat, release: release, telegram_message_id: 42, announcement_telegram_message_id: 43) }

  def reply_update(text:, to: 42, message_id: 100, **attrs)
    message_update(text: text, message_id: message_id, reply_to_message: { message_id: to }, **attrs)
  end

  it "stores a reply to the shared link exactly as written and has it scored" do
    sent_at = Time.zone.local(2026, 10, 13, 18, 0)

    dispatch(reply_update(text: "Ну це прям 🔥, 9/10", date: sent_at.to_i))

    review = Review.sole
    expect(review).to have_attributes(chat: chat, release: release, user: User.find_by!(telegram_id: "555"), score: nil)
    expect(review.messages.sole).to have_attributes(
      release_share: share, telegram_message_id: 100, source: "text", text: "Ну це прям 🔥, 9/10", sent_at: sent_at
    )
    expect(ScoreReviewJob).to have_been_enqueued.with(review)
  end

  it "counts a reply to the bot's announcement too" do
    dispatch(reply_update(text: "мід", to: 43))

    expect(Review.sole.messages.sole.release_share).to eq(share)
  end

  it "widens the same review with a second reply" do
    dispatch(reply_update(text: "спочатку не зайшло", message_id: 100))
    dispatch(reply_update(text: "а на третій раз кайф", message_id: 101))

    expect(Review.sole.messages.order(:id).pluck(:text)).to eq([ "спочатку не зайшло", "а на третій раз кайф" ])
    expect(ScoreReviewJob).to have_been_enqueued.with(Review.sole).twice
  end

  it "widens the same review from a reply under a later share, remembering which share" do
    reshare = create(:release_share, chat: chat, release: release, telegram_message_id: 200)

    dispatch(reply_update(text: "перший раз: 5", to: 42, message_id: 100))
    dispatch(reply_update(text: "тепер вже 8", to: 200, message_id: 201))

    expect(Review.sole.messages.order(:id).map(&:release_share)).to eq([ share, reshare ])
  end

  it "keeps separate reviews per chat" do
    other_chat = create(:chat, telegram_id: "-100777", camerton_enabled: true, mode: :quiet)
    create(:release_share, chat: other_chat, release: release, telegram_message_id: 42)

    dispatch(reply_update(text: "топ"))
    dispatch(reply_update(text: "топ", chat: telegram_chat(id: -100_777)))

    expect(Review.where(release: release).pluck(:chat_id)).to contain_exactly(chat.id, other_chat.id)
  end

  it "replaces the text and re-scores when the reply is edited" do
    dispatch(reply_update(text: "6/10"))
    clear_enqueued_jobs

    dispatch(edited_message_update(text: "7/10", message_id: 100, reply_to_message: { message_id: 42 }))

    expect(ReviewMessage.sole.text).to eq("7/10")
    expect(ScoreReviewJob).to have_been_enqueued.with(Review.sole)
  end

  it "doesn't store or score a redelivered reply again" do
    dispatch(reply_update(text: "6/10"))
    clear_enqueued_jobs

    dispatch(reply_update(text: "6/10"))

    expect(ReviewMessage.count).to eq(1)
    expect(ScoreReviewJob).not_to have_been_enqueued
  end

  it "treats a reply that shares a new link as a share, not feedback" do
    dispatch(reply_update(text: "краще ось це https://music.youtube.com/watch?v=lYBUbBu4W08"))

    expect(Review.count).to eq(0)
    expect(ReleaseShare.count).to eq(2)
  end

  it "ignores replies without text, replies to other messages and plain messages" do
    dispatch(message_update(message_id: 100, text: nil, sticker: { file_id: "x" }, reply_to_message: { message_id: 42 }))
    dispatch(reply_update(text: "ахаха", to: 999, message_id: 101))
    dispatch(message_update(text: "просто кажу", message_id: 102))

    expect([ Review.count, ReviewMessage.count ]).to eq([ 0, 0 ])
  end

  it "does nothing in a chat with Camerton off" do
    chat.update!(camerton_enabled: false)

    dispatch(reply_update(text: "9/10"))

    expect(Review.count).to eq(0)
  end
end
