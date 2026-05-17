require "test_helper"

class MessageRecorderTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
    @user = users(:one)
    @parent = @chat.messages.create!(
      role: :user,
      user: @user,
      content: "оригінал",
      telegram_message_id: 100
    )
  end

  test "records reply link when parent message exists" do
    telegram_message = {
      message_id: 101,
      text: "відповідь",
      reply_to_message: { message_id: 100, from: { first_name: "Test" }, text: "оригінал" }
    }

    message = MessageRecorder.new(
      chat: @chat,
      telegram_message: telegram_message,
      user: @user,
      role: :user
    ).record

    assert_equal @parent, message.reply_to
    assert_nil message.reply_snapshot
    assert_equal 101, message.telegram_message_id
  end

  test "stores reply snapshot when parent is missing" do
    telegram_message = {
      message_id: 102,
      text: "відповідь",
      reply_to_message: { message_id: 999, from: { first_name: "Іван" }, text: "старе" }
    }

    message = MessageRecorder.new(
      chat: @chat,
      telegram_message: telegram_message,
      user: @user,
      role: :user
    ).record

    assert_nil message.reply_to
    assert_equal 999, message.reply_snapshot["telegram_message_id"]
    assert_equal "Іван", message.reply_snapshot["user_name"]
    assert_equal "старе", message.reply_snapshot["content"]
  end
end
