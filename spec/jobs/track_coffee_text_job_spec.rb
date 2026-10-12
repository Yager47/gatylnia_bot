require "rails_helper"

RSpec.describe TrackCoffeeTextJob do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, first_name: "Петро", last_name: nil) }
  let(:sent_at) { Time.zone.local(2026, 10, 12, 9, 0) }
  let(:classifier) { instance_double(Activities::CoffeeTextClassifier) }

  before do
    allow(Activities::CoffeeTextClassifier).to receive(:new).and_return(classifier)
  end

  def message_with(text, telegram_message_id: 42)
    create(:message, chat: chat, user: user, content: text, telegram_message_id: telegram_message_id)
  end

  def classify_as(coffee:, ordinal: nil)
    allow(classifier).to receive(:call).and_return(Activities::CoffeeTextClassifier::Result.new(coffee: coffee, ordinal: ordinal))
  end

  def perform(message)
    described_class.perform_now(message, sent_at: sent_at)
  end

  def sent_texts
    fake_telegram.sent_messages.map { |params| params[:text] }
  end

  context "when the message is about drinking coffee" do
    before { classify_as(coffee: true, ordinal: 2) }

    it "records one cup and confirms with today's total" do
      create(:activity, chat: chat, user: user, occurred_at: sent_at - 2.hours)

      perform(message_with("Друга кава"))

      expect(Activity.coffee.last).to have_attributes(
        user: user, source: "text", telegram_message_id: 42, occurred_at: sent_at, amount: 1, details: { "ordinal" => 2 }
      )
      expect(sent_texts).to eq([ "☕ Петро: 2 за сьогодні" ])
      expect(chat.messages.assistant.last.content).to eq("☕ Петро: 2 за сьогодні")
    end

    it "counts one cup even when the message names a number" do
      perform(message_with("випив 2 каву"))

      expect(Activity.coffee.sole.amount).to eq(1)
      expect(sent_texts).to eq([ "☕ Петро: 1 за сьогодні" ])
    end

    it "does nothing when run again for the same message" do
      message = message_with("Друга кава")

      2.times { perform(message) }

      expect(Activity.count).to eq(1)
      expect(sent_texts.size).to eq(1)
      expect(classifier).to have_received(:call).once
    end

    it "rolls the record back when sending fails, so a retry starts clean" do
      allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "down")

      # perform_now retries via a scheduled job; the first attempt's effect is what matters here.
      perform(message_with("Друга кава"))

      expect(Activity.count).to eq(0)
    end
  end

  context "when the message isn't about drinking coffee" do
    before do
      classify_as(coffee: false)
      allow(Ai).to receive(:reply_in).and_return("Хочеш кави, то йди зроби")
    end

    it "replies in character when the bot is mentioned" do
      perform(message_with("@test_bot хочу кави"))

      expect(Activity.count).to eq(0)
      expect(sent_texts).to eq([ "Хочеш кави, то йди зроби" ])
    end

    it "replies in character by chance otherwise" do
      allow_any_instance_of(described_class).to receive(:rand).and_return(0.1)

      perform(message_with("хочу кави"))

      expect(sent_texts).to eq([ "Хочеш кави, то йди зроби" ])
    end

    it "stays silent when the chance doesn't hit" do
      allow_any_instance_of(described_class).to receive(:rand).and_return(0.9)

      perform(message_with("хочу кави"))

      expect(sent_texts).to be_empty
    end
  end
end
