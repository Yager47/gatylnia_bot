require "rails_helper"

RSpec.describe MemberNames do
  let(:chat) { create(:chat) }
  let(:petro) { create(:user, first_name: "Петро", last_name: "Тест", chats: [ chat ]) }
  let(:olga) { create(:user, first_name: "Ольга", last_name: nil, chats: [ chat ]) }

  before { chat.chat_users.find_by!(user: petro).update!(pseudonym: "Сер Гатило") }

  it "uses the pseudonym in this chat, else the Telegram name" do
    names = described_class.new(chat)

    expect([ names.name(petro), names.name(olga) ]).to eq([ "Сер Гатило", "Ольга" ])
    expect([ names.first_name(petro), names.first_name(olga) ]).to eq([ "Сер Гатило", "Ольга" ])
  end

  it "doesn't use a pseudonym from another chat" do
    other = create(:chat, users: [ petro ])

    expect(described_class.new(other).name(petro)).to eq("Петро Тест")
  end

  it "loads the pseudonyms once, however many names are asked for" do
    names = described_class.new(chat)
    petro
    olga

    expect(count_queries { 3.times { names.name(petro) && names.name(olga) } }).to eq(1)
  end

  it "is cached per loaded chat until it's reloaded" do
    expect(chat.member_names).to be(chat.member_names)
    expect(chat.reload.member_names.name(petro)).to eq("Сер Гатило")
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
