require "rails_helper"

RSpec.describe Camerton::SharerNotice do
  let(:chat) { create(:chat) }
  let(:release) { create(:release) }
  let(:reviewer) { create(:user, username: "reviewer") }
  let(:review) { create(:review, chat: chat, release: release, user: reviewer, score: 7) }

  def share_by(user, chat: self.chat)
    create(:release_share, chat: chat, release: release, user: user)
  end

  def sent
    fake_telegram.sent_messages
  end

  it "replies to the review's latest message, mentioning the sharer" do
    share = share_by(create(:user, username: "olya"))
    create(:review_message, review: review, release_share: share, telegram_message_id: 100, sent_at: 2.days.ago)
    create(:review_message, review: review, release_share: share, telegram_message_id: 101, sent_at: 1.hour.ago)

    described_class.new(review).call

    expect(sent.sole).to include(chat_id: chat.telegram_id, text: "@olya, твій реліз оцінили на 7/10 👍", parse_mode: "HTML")
    expect(sent.sole[:reply_parameters].message_id).to eq(101)
    expect(chat.messages.assistant.sole.content).to eq("@olya, твій реліз оцінили на 7/10 👍")
  end

  it "mentions everyone who shared the release here once, except the reviewer" do
    olya = create(:user, username: "olya")
    ivan = create(:user, username: "ivan")
    share = share_by(olya)
    share_by(ivan)
    share_by(olya)
    share_by(reviewer)
    share_by(create(:user, username: "elsewhere"), chat: create(:chat))
    create(:review_message, review: review, release_share: share)

    described_class.new(review).call

    expect(sent.sole[:text]).to eq("@olya, @ivan, ваш реліз оцінили на 7/10 👍")
  end

  it "mentions a sharer without a username with an escaped link" do
    share = share_by(create(:user, username: nil, telegram_id: "777", first_name: "<Іван & Co>", last_name: nil))
    create(:review_message, review: review, release_share: share)
    review.update!(score: 10)

    described_class.new(review).call

    expect(sent.sole[:text]).to eq(%(<a href="tg://user?id=777">&lt;Іван &amp; Co&gt;</a>, твій реліз оцінили на 10/10 🔥))
  end

  it "stays quiet when the reviewer is the only sharer" do
    create(:review_message, review: review, release_share: share_by(reviewer))

    described_class.new(review).call

    expect(sent).to be_empty
  end

  it "stays quiet without a score" do
    create(:review_message, review: review, release_share: share_by(create(:user)))
    review.update!(score: nil)

    described_class.new(review).call

    expect(sent).to be_empty
  end

  it "only logs a failure and keeps no assistant message" do
    create(:review_message, review: review, release_share: share_by(create(:user)))
    allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "Telegram unreachable")
    allow(Rails.logger).to receive(:warn)

    expect { described_class.new(review).call }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(/Telegram unreachable/)
    expect(chat.messages.assistant).to be_empty
  end
end
