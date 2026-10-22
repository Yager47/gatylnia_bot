require "rails_helper"

RSpec.describe Zhmykhcoins::WeeklySummary do
  let(:chat) { create(:chat) }
  # Monday 10:00 Kyiv: the summary covers Mon 12 – Sun 18 October.
  let(:now) { Time.zone.local(2026, 10, 19, 10, 0) }
  let(:last_week) { Time.zone.local(2026, 10, 14, 12, 0) }

  def member(name)
    create(:user, first_name: name, last_name: nil, chats: [ chat ])
  end

  def point(user, amount, at: last_week, giver: nil)
    create(:point, chat: chat, user: user, amount: amount, giver: giver, created_at: at)
  end

  def summary
    described_class.new(chat, now: now).text
  end

  describe "#text" do
    it "names the week's top earner, each member's change with their balance, and the most generous giver" do
      petro = member("Петро")
      olga = member("Ольга")
      ivan = member("Іван")
      point(petro, 1000, at: now - 1.month)
      point(petro, 300, giver: ivan)
      point(petro, 40)
      point(olga, -50, giver: ivan)
      point(olga, 100, giver: petro)
      point(olga, -100)

      expect(summary).to eq(<<~TEXT.strip)
        💰 Жмихкоїни за минулий тиждень:

        👑 Жмихкоїн тижня: Петро, +340 жмихкоїнів

        Петро: +340 (разом 1340)
        Ольга: -50 (разом -50)

        🎁 Найщедріший: Іван, роздав 300
      TEXT
    end

    it "counts only the past Kyiv week, Monday to Sunday" do
      petro = member("Петро")
      point(petro, 1, at: Time.zone.local(2026, 10, 11, 23, 59))
      point(petro, 2, at: Time.zone.local(2026, 10, 12, 0, 0))
      point(petro, 4, at: Time.zone.local(2026, 10, 18, 23, 59))
      point(petro, 8, at: Time.zone.local(2026, 10, 19, 0, 0))

      expect(summary).to include("Петро: +6 (разом 15)")
    end

    it "leaves out members whose balance didn't move and has no king when nobody came out ahead" do
      petro = member("Петро")
      olga = member("Ольга")
      point(petro, 50)
      point(petro, -50)
      point(olga, -10)

      expect(summary).to eq("💰 Жмихкоїни за минулий тиждень:\n\nОльга: -10 (разом -10)")
    end

    it "is nil when nothing moved, and ignores other chats" do
      create(:point, chat: create(:chat), amount: 50, created_at: last_week)

      expect(summary).to be_nil
    end

    it "takes four queries however many members there are" do
      3.times { |n| point(member("Член #{n}"), 10, giver: member("Дарувальник #{n}")) }

      expect(count_queries { summary }).to eq(4)
    end
  end

  describe "#deliver" do
    it "sends the summary once per Monday" do
      point(member("Петро"), 10)
      expected = summary

      2.times { described_class.new(chat, now: now).deliver }

      expect(fake_telegram.sent_messages.map { |params| params[:text] }).to eq([ expected ])
      expect(chat.reload.points_summary_sent_on).to eq(now.to_date)
      expect(chat.messages.assistant.sole.content).to eq(expected)
    end

    it "sends nothing in a quiet week but still marks it done" do
      described_class.new(chat, now: now).deliver

      expect(fake_telegram.sent_messages).to be_empty
      expect(chat.reload.points_summary_sent_on).to eq(now.to_date)
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
