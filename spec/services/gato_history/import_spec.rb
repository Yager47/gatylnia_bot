require "rails_helper"

RSpec.describe GatoHistory::Import do
  let(:chat) { create(:chat) }
  let(:other_chat) { create(:chat) }
  let(:petro) { create(:user, telegram_id: "555", first_name: "Петро", chats: [ chat ]) }
  let(:olia) { create(:user, telegram_id: "666", first_name: "Оля", chats: [ chat ]) }
  let(:from) { Time.zone.local(2026, 1, 1) }
  let(:to) { Time.zone.local(2026, 4, 11, 15, 29, 44) }

  before do
    petro
    olia
  end

  def message(text, at:, sender: "555", name: "Петро")
    GatoHistory::ExportParser::Message.new(
      telegram_message_id: rand(1..1_000_000), sender_id: sender, sender_name: name, sent_at: at, text: text
    )
  end

  def import(messages, dry_run: false)
    described_class.new(chat: chat, messages: messages, from: from, to: to, dry_run: dry_run).call
  end

  it "creates an entry for each exact gato phrase, at the message's time" do
    at = Time.zone.local(2026, 2, 3, 10, 0)

    import([ message("Погатив", at: at), message("погатив вчора", at: at), message("Привіт", at: at) ])

    expect(chat.entries.sole).to have_attributes(user: petro, message: "Погатив", created_at: at, updated_at: at)
  end

  it "applies \"видали гатіння\" to the sender's own last entry only" do
    report = import([
      message("гатю", at: from + 1.hour),
      message("гатю", at: from + 2.hours, sender: "666", name: "Оля"),
      message("какаю", at: from + 3.hours),
      message("Видали гатіння", at: from + 4.hours),
      message("@GatylniaBot видали гатіння", at: from + 5.hours)
    ])

    expect(chat.entries.pluck(:user_id, :message)).to contain_exactly([ petro.id, "гатю" ], [ olia.id, "гатю" ])
    expect(report.removals).to eq(1)
  end

  it "only reads messages in from...to" do
    import([ message("гатю", at: from - 1.second), message("гатю", at: from), message("гатю", at: to) ])

    expect(chat.entries.pluck(:created_at)).to eq([ from ])
  end

  it "replaces the period's existing entries and keeps the rest" do
    placeholder = create(:entry, chat: chat, user: petro, message: "Втрачене гатіння", created_at: from + 1.day)
    after_period = create(:entry, chat: chat, user: petro, created_at: to)
    other_chat_entry = create(:entry, chat: other_chat, user: petro, created_at: from + 1.day)

    report = import([ message("гатю", at: from + 2.days) ])

    expect(report.deleted).to eq("Втрачене гатіння" => 1)
    expect(Entry.exists?(placeholder.id)).to be(false)
    expect(chat.entries.pluck(:id)).to include(after_period.id)
    expect(Entry.exists?(other_chat_entry.id)).to be(true)
  end

  it "gives the same result when run twice" do
    messages = [ message("гатю", at: from + 1.hour), message("какаю", at: from + 2.hours, sender: "666") ]

    import(messages)

    expect { import(messages) }.not_to(change { chat.entries.order(:created_at).pluck(:user_id, :message, :created_at) })
  end

  it "skips senders who aren't members of the chat or have no id, and reports them" do
    create(:user, telegram_id: "777")

    report = import([
      message("гатю", at: from + 1.hour, sender: "777", name: "Чужий"),
      message("гатю", at: from + 2.hours, sender: nil, name: "Без фото")
    ])

    expect(chat.entries).to be_empty
    expect(report.skipped_senders).to eq("777" => 1, "Без фото" => 1)
  end

  it "reports per user what it creates" do
    report = import([ message("гатю", at: from + 1.hour), message("гатю", at: from + 2.hours) ])

    expect(report.created).to eq(petro => 2)
  end

  it "writes nothing on a dry run" do
    create(:entry, chat: chat, user: petro, message: "Втрачене гатіння", created_at: from + 1.day)

    report = nil
    expect { report = import([ message("гатю", at: from + 2.days) ], dry_run: true) }.not_to change(Entry, :count)
    expect(report).to have_attributes(deleted: { "Втрачене гатіння" => 1 }, created: { petro => 1 })
  end
end
