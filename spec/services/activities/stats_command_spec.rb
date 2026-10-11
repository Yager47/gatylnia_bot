require "rails_helper"

RSpec.describe Activities::StatsCommand do
  let(:chat) { create(:chat) }
  let(:petro) { create(:user, first_name: "Петро", last_name: nil) }
  let(:olha) { create(:user, first_name: "Ольга", last_name: nil) }

  def reply(command)
    described_class.new(command: command, chat: chat).call
  end

  it "lists coffee cups per user for the period" do
    create(:activity, chat: chat, user: petro, amount: 2)
    create(:activity, chat: chat, user: olha)

    expect(reply("кава за тиждень")).to eq("Кава за поточний тиждень:\n\nПетро: 2\nОльга: 1")
  end

  it "treats віджимання and відтискання as the same push-ups" do
    create(:activity, :push_ups, chat: chat, user: petro)

    expect(reply("віджимання за місяць")).to eq("Віджимання за поточний місяць:\n\nПетро: 1")
    expect(reply("відтискання за рік")).to eq("Відтискання за поточний рік:\n\nПетро: 1")
  end

  it "accepts день as сьогодні" do
    expect(reply("кава за день")).to eq(reply("кава за сьогодні"))
  end

  it "says so when nobody has activities in the period" do
    expect(reply("кава за сьогодні")).to eq("Кава за сьогодні:\n\nНікого.")
  end

  # Production runs on a UTC clock; Time.current must still give the Kyiv day.
  it "uses the Kyiv day" do
    travel_to Time.utc(2026, 10, 11, 22, 30) do # 01:30 on Oct 12 in Kyiv
      create(:activity, chat: chat, user: petro, occurred_at: Time.zone.local(2026, 10, 12, 0, 30))
      create(:activity, chat: chat, user: olha, occurred_at: Time.zone.local(2026, 10, 11, 23, 30))

      expect(reply("кава за сьогодні")).to eq("Кава за сьогодні:\n\nПетро: 1")
    end
  end

  it "returns nil for anything else" do
    expect(reply("гатуни за тиждень")).to be_nil
    expect(reply("кава за вічність")).to be_nil
    expect(reply("хто пив кава за тиждень")).to be_nil
  end
end
