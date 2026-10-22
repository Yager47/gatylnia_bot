require "rails_helper"

RSpec.describe ChatUser do
  let(:chat) { create(:chat) }

  def membership(pseudonym = nil, in_chat: chat)
    ChatUser.create!(chat: in_chat, user: create(:user), pseudonym: pseudonym)
  end

  it "squishes the pseudonym and stores a blank one as nil" do
    expect(membership("  Сер   Гатило ").pseudonym).to eq("Сер Гатило")
    expect(membership("   ").pseudonym).to be_nil
  end

  it "allows up to 32 characters" do
    expect(build(:chat_user, chat: chat, pseudonym: "я" * 32)).to be_valid
    expect(build(:chat_user, chat: chat, pseudonym: "я" * 33)).not_to be_valid
  end

  it "keeps pseudonyms unique per chat, whatever the case" do
    membership("Сер Гатило")

    expect(build(:chat_user, chat: chat, pseudonym: "сер гатило")).not_to be_valid
    expect(build(:chat_user, chat: create(:chat), pseudonym: "Сер Гатило")).to be_valid
    expect { membership(nil) && membership(nil) }.not_to raise_error
  end

  it "has a unique index behind the validation" do
    membership("Сер Гатило")
    duplicate = build(:chat_user, chat: chat, pseudonym: "СЕР ГАТИЛО")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
