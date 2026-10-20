require "rails_helper"

RSpec.describe Achievements::Overview do
  let(:chat) { create(:chat, camerton_enabled: true) }
  let(:members) { create_list(:user, 3, chats: [ chat ]) }

  def rule(code, secret: false)
    Struct.new(:code, :secret) do
      def title = "Ачівка #{code}"
      def description = "умова #{code}"
      def secret? = secret
    end.new(code, secret)
  end

  def text(rules)
    described_class.new(chat: chat, rules: rules).text
  end

  def earn(user, code, period: "2026-10", revoked: false)
    create(:achievement, chat: chat, user: user, code: code, period: period, revoked_at: (Time.current if revoked))
  end

  it "lists every achievement with how many members have earned it, counting each member once" do
    earn(members[0], "a")
    earn(members[0], "a", period: "2026-09")
    earn(members[1], "a")
    earn(members[2], "a", revoked: true)
    earn(create(:user), "b").update!(chat: create(:chat))

    expect(text([ rule("a"), rule("b") ])).to eq(<<~TEXT.chomp)
      🏆 Ачівки:

      • Ачівка a — умова a · здобули 2 з 3
      • Ачівка b — умова b · ще ніхто

      Твої — @test_bot мої ачівки
    TEXT
  end

  it "hides a secret achievement until someone here earns it" do
    expect(text([ rule("s", secret: true) ])).to include("• ??? — секретна ачівка")
    expect(text([ rule("s", secret: true) ])).not_to include("Ачівка s")

    earn(members[0], "s")

    expect(text([ rule("s", secret: true) ])).to include("• Ачівка s — умова s · здобули 1 з 3")
  end

  it "lists the real achievements" do
    expect(described_class.new(chat: chat).text).to include("• Пісенний Напівмарафонець — 21 оцінена пісня за місяць · ще ніхто")
  end
end
