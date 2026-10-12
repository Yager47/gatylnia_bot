require "rails_helper"

RSpec.describe ChatMembers::Resolver do
  let(:chat) { create(:chat) }
  let(:from) { { id: 555, username: "petro", first_name: "Петро", last_name: "Тест" }.with_indifferent_access }

  def resolve
    described_class.new(chat: chat, from: from).call
  end

  it "creates a new user and their membership" do
    user = resolve

    expect(user).to have_attributes(telegram_id: "555", username: "petro", first_name: "Петро", last_name: "Тест")
    expect(chat.users).to contain_exactly(user)
  end

  it "reuses a known user and adds them to a new chat" do
    existing = create(:user, telegram_id: "555", first_name: "Старе ім'я")

    expect(resolve).to eq(existing)
    expect(existing.reload.first_name).to eq("Старе ім'я")
    expect(chat.users).to contain_exactly(existing)
  end

  it "doesn't duplicate an existing membership" do
    user = create(:user, telegram_id: "555")
    ChatUser.create!(chat: chat, user: user)

    expect { resolve }.not_to change(ChatUser, :count)
  end

  # Simulates another job inserting the row between our find_by and INSERT.
  it "returns the existing user when it was created concurrently" do
    existing = create(:user, telegram_id: "555")
    allow(User).to receive(:find_by).and_return(nil)

    expect(resolve).to eq(existing)
    expect(User.count).to eq(1)
  end

  it "keeps a single membership when it was created concurrently" do
    user = create(:user, telegram_id: "555")
    ChatUser.create!(chat: chat, user: user)
    allow(ChatUser).to receive(:find_by).and_return(nil)

    expect { resolve }.not_to raise_error
    expect(ChatUser.where(chat: chat, user: user).count).to eq(1)
  end
end
