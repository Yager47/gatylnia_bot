require "rails_helper"
require Rails.root.join("db/migrate/20261012092848_remove_telegram_service_accounts_from_chats")

RSpec.describe RemoveTelegramServiceAccountsFromChats do
  let(:chat) { create(:chat) }
  let(:other_chat) { create(:chat) }

  def migrate
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  it "removes a service account that owns nothing, with its memberships" do
    anonymous = create(:user, telegram_id: "1087968824", first_name: "Group", chats: [ chat, other_chat ])

    migrate

    expect(User.exists?(anonymous.id)).to be(false)
    expect(ChatUser.where(user_id: anonymous.id)).to be_empty
  end

  it "keeps a service account that owns rows, but removes its memberships" do
    channel_bot = create(:user, telegram_id: "136817688", chats: [ chat ])
    create(:message, chat: chat, user: channel_bot)

    migrate

    expect(User.exists?(channel_bot.id)).to be(true)
    expect(channel_bot.chats.reload).to be_empty
  end

  it "leaves real members alone" do
    person = create(:user, telegram_id: "555", chats: [ chat ])

    migrate

    expect(chat.users.reload).to contain_exactly(person)
  end

  it "is safe to run twice" do
    create(:user, telegram_id: "777000", chats: [ chat ])

    migrate
    expect { migrate }.not_to raise_error
  end
end
