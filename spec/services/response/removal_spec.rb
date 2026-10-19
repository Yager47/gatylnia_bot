require "rails_helper"

RSpec.describe Response::Removal do
  let(:chat) { create(:chat, mode: :default) }
  let(:user) { create(:user, chats: [ chat ]) }
  let(:classifier) { instance_double(Removals::RequestClassifier) }

  def removal(text, reply_to_message: nil)
    described_class.new(user: user, text: text, chat: chat, reply_to_message: reply_to_message, classifier: classifier).call
  end

  def classifier_says(kind)
    allow(classifier).to receive(:call).and_return(kind)
  end

  it "ignores messages not addressed to the bot, and commands that aren't removals, without asking the AI" do
    allow(classifier).to receive(:call)

    expect(removal("видали останню каву")).to be_nil
    expect(removal("@test_bot кава за тиждень")).to be_nil
    expect(classifier).not_to have_received(:call)
  end

  it "removes the author's latest coffee when the AI reads a coffee removal" do
    classifier_says("coffee")
    older = create(:activity, chat: chat, user: user, occurred_at: 2.hours.ago)
    latest = create(:activity, chat: chat, user: user, occurred_at: 1.hour.ago)
    someone_elses = create(:activity, chat: chat, occurred_at: 1.minute.ago)

    expect(removal("@test_bot прибери останню каву")).to start_with("Видалив твою останню каву.")
    expect(Activity.where(id: [ older.id, latest.id, someone_elses.id ]).ids).to contain_exactly(older.id, someone_elses.id)
    expect(classifier).to have_received(:call).with("прибери останню каву", kinds: %w[coffee gato])
  end

  it "removes the author's latest gato in this chat" do
    classifier_says("gato")
    older = create(:entry, chat: chat, user: user, created_at: 1.day.ago)
    create(:entry, chat: chat, user: user)
    other_chat = create(:entry, user: user)

    expect(removal("@test_bot скасуй гатіння, я пожартував")).to eq("Твоє останнє гатіння видалено. \nТіряйся")
    expect(Entry.ids).to contain_exactly(older.id, other_chat.id)
  end

  it "says what it can do instead when the AI finds no removal of the author's own latest record" do
    classifier_says(nil)
    create(:activity, chat: chat)

    expect(removal("@test_bot видали каву Олі")).to eq("Можу прибрати лише твою останню каву чи твоє останнє гатіння.")
    expect(Activity.count).to eq(1)
  end

  it "says what it can do when OpenAI fails, removing nothing" do
    allow(classifier).to receive(:call).and_raise(OpenAI::Errors::APIConnectionError.new(url: URI("https://api.openai.com"), request: nil))
    create(:activity, chat: chat, user: user)

    expect(removal("@test_bot видали каву")).to start_with("Можу прибрати лише")
    expect(Activity.count).to eq(1)
  end

  it "offers coffee and gato only in default mode" do
    chat.update!(mode: :accountant)
    allow(classifier).to receive(:call)

    expect(removal("@test_bot видали каву")).to be_nil
    expect(classifier).not_to have_received(:call)
  end

  describe "a review" do
    let(:chat) { create(:chat, mode: :quiet, camerton_enabled: true) }
    let(:release) { create(:release, :resolved) }
    let(:share) { create(:release_share, chat: chat, release: release, telegram_message_id: 7) }

    before { classifier_says("review") }

    it "removes the author's review of the replied-to release, its messages and the bot's reactions" do
      review = create(:review, chat: chat, release: release, user: user, score: 8)
      create(:review_message, review: review, release_share: share, telegram_message_id: 8)
      someone_elses = create(:review, chat: chat, release: release, score: 3)

      expect(removal("@test_bot видали мою оцінку", reply_to_message: { message_id: 7 })).to eq("Видалив твою оцінку: 🎵 Queen — Bohemian Rhapsody")
      expect(Review.ids).to eq([ someone_elses.id ])
      expect(ReviewMessage.count).to eq(0)
      expect(fake_telegram.calls).to include([ :set_message_reaction, { chat_id: chat.telegram_id, message_id: 8, reaction: [] } ])
      expect(classifier).to have_received(:call).with("видали мою оцінку", kinds: %w[review])
    end

    it "says so when the author hasn't reviewed it" do
      share

      expect(removal("@test_bot видали мою оцінку", reply_to_message: { message_id: 7 })).to eq("Ти ще не оцінював 🎵 Queen — Bohemian Rhapsody")
    end

    it "asks for a reply to a release when there is none" do
      expect(removal("@test_bot видали мою оцінку")).to eq(described_class::REPLY_TO_RELEASE)
      expect(removal("@test_bot видали мою оцінку", reply_to_message: { message_id: 999 })).to eq(described_class::REPLY_TO_RELEASE)
    end

    it "offers reviews only with Camerton on" do
      chat.update!(camerton_enabled: false)

      expect(removal("@test_bot видали мою оцінку", reply_to_message: { message_id: 7 })).to be_nil
    end
  end
end
