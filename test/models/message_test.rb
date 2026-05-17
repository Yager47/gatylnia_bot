require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @chat = chats(:one)
    @ivan = users(:one)
    @petro = users(:two)
    @parent = @chat.messages.create!(role: :user, user: @ivan, content: "піду спати")
  end

  test "ai_context includes reply chain" do
    message = @chat.messages.create!(
      role: :user,
      user: @petro,
      content: "ні, не підеш",
      reply_to: @parent
    )

    context = message.ai_context

    assert_includes context, "відповідь"
    assert_includes context, @ivan.name
    assert_includes context, "піду спати"
    assert_includes context, "ні, не підеш"
  end

  test "ai_context includes reactions" do
    message = @chat.messages.create!(
      role: :user,
      user: @ivan,
      content: "жарт",
      reactions: { "users" => { "1" => { "name" => "Іван", "emojis" => ["👍"] } }, "totals" => { "👍" => 1 } }
    )

    assert_includes message.ai_context, "[реакції:"
    assert_includes message.ai_context, "👍"
  end
end
