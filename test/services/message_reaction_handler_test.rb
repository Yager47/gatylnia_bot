require "test_helper"

class MessageReactionHandlerTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
    @user = users(:one)
    @message = @chat.messages.create!(
      role: :user,
      user: @user,
      content: "жарт",
      telegram_message_id: 200
    )
  end

  test "stores user reaction" do
    update = {
      chat: { id: @chat.telegram_id },
      message_id: 200,
      user: { id: @user.telegram_id, first_name: "Test" },
      new_reaction: [{ type: "emoji", emoji: "👍" }]
    }

    MessageReactionHandler.new(update).call
    @message.reload

    assert_equal ["👍"], @message.reactions["users"][@user.telegram_id.to_s]["emojis"]
    assert_equal 1, @message.reactions["totals"]["👍"]
  end

  test "stores anonymous reaction totals" do
    update = {
      chat: { id: @chat.telegram_id },
      message_id: 200,
      reactions: [{ type: "emoji", emoji: "🔥", total_count: 4 }]
    }

    MessageReactionHandler.new(update, count_mode: true).call
    @message.reload

    assert_equal 4, @message.reactions["totals"]["🔥"]
  end
end
