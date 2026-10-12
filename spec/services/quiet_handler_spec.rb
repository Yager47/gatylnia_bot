require "rails_helper"

RSpec.describe QuietHandler do
  # Through the dispatcher, so the chat and user get created like in production.
  def dispatch(update)
    TelegramUpdates::Dispatcher.new(update.deep_stringify_keys).call
  end

  let!(:chat) { create(:chat, telegram_id: telegram_chat[:id].to_s, mode: :quiet) }

  def sent_texts
    fake_telegram.sent_messages.map { |params| params[:text] }
  end

  it "records a message without replying, even to an exact-match phrase" do
    dispatch(message_update(text: "Ало"))

    expect(sent_texts).to be_empty
    expect(Message.sole).to have_attributes(role: "user", content: "Ало", user: User.sole)
    expect(chat.users).to contain_exactly(User.sole)
  end

  it "doesn't call the AI when the bot is mentioned" do
    dispatch(message_update(text: "@test_bot як справи"))

    expect(sent_texts).to be_empty
  end

  it "answers bot commands" do
    dispatch(message_update(text: "@test_bot камертон: увімкни"))

    expect(sent_texts).to eq([ "Камертон увімкнено." ])
    expect(chat.reload.camerton_enabled).to be(true)
  end

  it "can switch back to another mode" do
    dispatch(message_update(text: "@test_bot режим: звичайний"))

    expect(sent_texts).to eq([ "Активовано звичайний режим." ])
    expect(chat.reload).to be_default
  end

  it "ignores edits" do
    dispatch(edited_message_update(text: "@test_bot камертон: увімкни"))

    expect(sent_texts).to be_empty
    expect(chat.reload.camerton_enabled).to be(false)
  end
end
