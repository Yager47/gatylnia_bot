require "rails_helper"

RSpec.describe NegatePreSupergroupMessageIdsJob do
  it "negates the chat's message numbers from before it became a supergroup" do
    chat = create(:chat, telegram_type: "supergroup", supergroup_since: 1.hour.ago)
    share = create(:release_share, chat: chat, telegram_message_id: 15_000, shared_at: 2.hours.ago)

    described_class.perform_now(chat)

    expect(share.reload.telegram_message_id).to eq(-15_000)
  end
end
