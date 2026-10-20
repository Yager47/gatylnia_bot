require "rails_helper"

RSpec.describe Achievements::Checker do
  # Stands in for a real rule: whoever is in winners qualifies.
  let(:rule) do
    Class.new(Achievements::Rule) do
      attr_accessor :winners

      def code = "test"
      def title = "Тест"
      def description = "умова тесту"
      def period_kind = :month
      def winner_ids(_chat, _period) = winners
    end.new.tap { |rule| rule.winners = [] }
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

  describe "a rule with levels" do
    let(:rule) do
      Class.new(Achievements::Rule) do
        attr_accessor :by_user

        def code = "grows"
        def title = "Росте"
        def description = "росте"
        def period_kind = :week
        def levels(_chat, _period) = by_user
        def level_line(mention, level) = "📈 #{mention}: #{level}"
      end.new.tap { |rule| rule.by_user = {} }
    end

    it "announces each rise, stores a fall silently, and takes it back at zero" do
      rule.by_user = { olya.id => 1 }
      check
      rule.by_user = { olya.id => 3 }
      check
      rule.by_user = { olya.id => 2 }
      check
      expect(chat.achievements.sole).to have_attributes(level: 2, period: "2026-W43")

      rule.by_user = {}
      check

      expect(sent_texts).to eq([
        "🏆 @olya отримує ачівку «Росте»: росте",
        "📈 @olya: 3",
        "↩️ @olya втрачає ачівку «Росте»: вже не росте"
      ])
    end
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

  it "registers every rule once, with its goal" do
    expect(Achievements::RULES.to_h { |rule| [ rule.code, rule.goal ] }).to eq(
      "song_half_marathon" => 21, "song_marathon" => 42, "genre_tourist" => 10, "chatterbox" => 20,
      "first_listener" => 5, "lightning" => 5, "rescuer" => 3, "archaeologist" => 5,
      "bubble_exit" => 3, "long_critic" => 5, "necromancer" => 5, "turncoat" => nil
    )
    expect(Achievements::RULES.map(&:code)).to eq(Achievements::RULES.map(&:code).uniq)
  end

  it "runs every real rule against the database" do
    expect { described_class.new(chat, now: now).call }.not_to raise_error
  end
end
