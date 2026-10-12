require "rails_helper"

RSpec.describe Response::Gato do
  let(:chat) { create(:chat) }
  let(:other_chat) { create(:chat) }
  let(:user) { create(:user, chats: [ chat, other_chat ]) }

  def remove_entry_in(target_chat)
    described_class.new(user: user, text: "видали гатіння", original_text: "Видали гатіння", chat: target_chat).call
  end

  describe "видали гатіння" do
    it "deletes the user's last entry in this chat, not a newer one in another chat" do
      older_here = create(:entry, chat: chat, user: user)
      newer_elsewhere = create(:entry, chat: other_chat, user: user)

      expect(remove_entry_in(chat)).to start_with("Твоє останнє гатіння видалено")
      expect(Entry.exists?(older_here.id)).to be(false)
      expect(Entry.exists?(newer_elsewhere.id)).to be(true)
    end

    it "doesn't delete another user's entry" do
      someone_else = create(:entry, chat: chat)

      expect(remove_entry_in(chat)).to eq("Ти ще тут не гатив, придурок")
      expect(Entry.exists?(someone_else.id)).to be(true)
    end

    it "says there is nothing to delete when the user only has entries in other chats" do
      create(:entry, chat: other_chat, user: user)

      expect { remove_entry_in(chat) }.not_to change(Entry, :count)
      expect(remove_entry_in(chat)).to eq("Ти ще тут не гатив, придурок")
    end
  end

  describe "removing the latest entry" do
    it "picks the newest by created_at, not by id" do
      newer = create(:entry, chat: chat, user: user, created_at: 1.minute.ago)
      older = create(:entry, chat: chat, user: user, created_at: 1.hour.ago)

      remove_entry_in(chat)

      expect(Entry.exists?(newer.id)).to be(false)
      expect(Entry.exists?(older.id)).to be(true)
    end
  end

  describe "explaining how to log a gato" do
    def reply_to(text, in_chat:)
      described_class.new(user: user, text: text, original_text: text, chat: in_chat).call
    end

    it "explains in a chat less than a week old" do
      expect(reply_to("гатю трохи", in_chat: chat)).to include("видали гатіння")
    end

    it "stays quiet in an older chat" do
      chat.update!(created_at: 8.days.ago)

      expect(reply_to("гатю трохи", in_chat: chat)).to be_nil
    end
  end
end
