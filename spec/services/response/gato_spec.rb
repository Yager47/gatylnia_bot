require "rails_helper"

RSpec.describe Response::Gato do
  let(:chat) { create(:chat) }
  let(:other_chat) { create(:chat) }
  let(:user) { create(:user, chats: [ chat, other_chat ]) }

  # Returns the reply text; the handler raises Success to deliver it.
  def remove_entry_in(target_chat)
    described_class.new(user: user, text: "видали гатіння", original_text: "Видали гатіння", chat: target_chat).process
    nil
  rescue Success => e
    e.message
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
end
