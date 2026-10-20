require "rails_helper"

RSpec.describe Achievements::Checker do
  # Stands in for a real rule: whoever is in winners qualifies.
  let(:rule) do
    Struct.new(:winners) do
      def code = "test"
      def title = "Тест"
      def description = "умова тесту"
      def period_kind = :month
      def winner_ids(_chat, _period) = winners
    end.new([])
  end

  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:olya) { create(:user, username: "olya") }
  let(:petro) { create(:user, username: "petro") }
  let(:now) { Time.zone.local(2026, 10, 20, 12) }

  def check(at: now)
    described_class.new(chat, rules: [ rule ], now: at).call
  end

  def sent_texts
    fake_telegram.sent_messages.map { |message| message[:text] }
  end

  it "awards new winners in one message, once" do
    rule.winners = [ olya.id, petro.id ]

    check
    check

    expect(sent_texts).to eq([ "🏆 @olya отримує ачівку «Тест»: умова тесту\n🏆 @petro отримує ачівку «Тест»: умова тесту" ])
    expect(fake_telegram.sent_messages.sole[:parse_mode]).to eq("HTML")
    expect(chat.achievements.active.pluck(:user_id, :code, :period)).to contain_exactly([ olya.id, "test", "2026-10" ], [ petro.id, "test", "2026-10" ])
    expect(chat.messages.assistant.sole.telegram_message_id).to be_present
  end

  it "takes an achievement back when its condition stops holding, and restores it when it holds again" do
    rule.winners = [ olya.id ]
    check

    rule.winners = []
    check(at: now + 1.hour)
    achievement = chat.achievements.sole
    expect(achievement.revoked_at).to eq(now + 1.hour)
    expect(sent_texts.last).to eq("↩️ @olya втрачає ачівку «Тест»: вже не умова тесту")

    rule.winners = [ olya.id ]
    check(at: now + 2.hours)
    expect(achievement.reload).to have_attributes(revoked_at: nil, awarded_at: now + 2.hours)
    expect(sent_texts.last).to eq("🏆 @olya отримує ачівку «Тест»: умова тесту")
    expect(sent_texts.size).to eq(3)
  end

  it "leaves closed periods alone" do
    rule.winners = [ olya.id ]
    check

    rule.winners = []
    check(at: now + 1.month)

    expect(chat.achievements.sole).to have_attributes(period: "2026-10", revoked_at: nil)
    expect(sent_texts.size).to eq(1)
  end

  it "rolls everything back when the message fails to send, so a retry announces it" do
    rule.winners = [ olya.id ]
    allow(fake_telegram).to receive(:send_message).and_raise(Faraday::ConnectionFailed, "down")

    expect { check }.to raise_error(Faraday::ConnectionFailed)
    expect(Achievement.count).to eq(0)
    expect(Message.count).to eq(0)
  end

  it "does nothing with Camerton off" do
    chat.update!(camerton_enabled: false)
    rule.winners = [ olya.id ]

    check

    expect(chat.achievements).to be_empty
    expect(fake_telegram.sent_messages).to be_empty
  end

  it "registers the song marathons" do
    expect(Achievements::RULES.map(&:code)).to eq(%w[song_half_marathon song_marathon])
    expect(Achievements::RULES.map(&:goal)).to eq([ 21, 42 ])
  end
end
