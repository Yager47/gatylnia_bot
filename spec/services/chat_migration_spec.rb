require "rails_helper"

RSpec.describe ChatMigration do
  let!(:chat) { create(:chat, telegram_id: "-4828587211", telegram_type: "group", title: "Камертон", mode: :quiet) }

  def migrate
    described_class.new(from: -4_828_587_211, to: -1_004_499_357_183).call
  end

  it "points the chat at the new id and type, noting when, and keeps everything else" do
    freeze_time do
      expect(migrate).to eq(chat)
      expect(chat.reload).to have_attributes(telegram_id: "-1004499357183", telegram_type: "supergroup", supergroup_since: Time.current,
        title: "Камертон", mode: "quiet")
    end
  end

  it "does nothing the second time" do
    migrate

    expect(migrate).to be_nil
    expect(Chat.sole.telegram_id).to eq("-1004499357183")
  end

  it "does nothing for a chat the bot doesn't know" do
    expect(described_class.new(from: -1, to: -1_002).call).to be_nil
    expect(Chat.sole).to eq(chat)
  end

  it "leaves both rows and logs when the new id already has its own" do
    other = create(:chat, telegram_id: "-1004499357183")
    allow(Rails.logger).to receive(:error)

    expect(migrate).to be_nil
    expect([ chat.reload.telegram_id, other.reload.telegram_id ]).to eq([ "-4828587211", "-1004499357183" ])
    expect(Rails.logger).to have_received(:error).with(/already has its own row/)
  end
end
