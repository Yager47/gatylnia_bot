require "rails_helper"

# The unique indexes are what make find_by || create_or_find_by! race-safe,
# so check the database itself rejects duplicates (model validations don't).
RSpec.describe "Unique Telegram identities" do
  it "allows one chat per telegram_id" do
    create(:chat, telegram_id: "-100")

    expect { create(:chat, telegram_id: "-100") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows one user per telegram_id" do
    create(:user, telegram_id: "555")

    expect { create(:user, telegram_id: "555") }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows one membership per chat and user" do
    chat = create(:chat)
    user = create(:user)
    ChatUser.create!(chat: chat, user: user)

    expect { ChatUser.create!(chat: chat, user: user) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
