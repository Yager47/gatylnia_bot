class RemoveChatsFromUsers < ActiveRecord::Migration[8.0]
  def up
    User.find_each do |user|
      ChatUser.create!(chat_id: user.chat_id, user: user)
    end

    remove_reference :users, :chat
  end

  def down
    add_reference :users, :chat, foreign_key: true, index: true

    User.find_each do |user|
      chat = user.chats.first
      user.update!(chat: chat)
    end
  end
end
