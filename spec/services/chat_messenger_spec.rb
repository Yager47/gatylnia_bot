require "rails_helper"

RSpec.describe ChatMessenger do
  let(:chat) { create(:chat) }

  it "sends the message and stores Telegram's message id on it" do
    message = chat.messages.create!(role: :assistant, content: "Ало")

    described_class.new(chat: chat).deliver(message)

    expect(fake_telegram.sent_messages).to eq([ { chat_id: chat.telegram_id, text: "Ало" } ])
    expect(message.reload.telegram_message_id).to eq(1001)
  end

  it "replies in a thread when given a message to answer" do
    message = chat.messages.create!(role: :assistant, content: "Ало")

    described_class.new(chat: chat).deliver(message, reply_to: 42)

    expect(fake_telegram.sent_messages.sole[:reply_parameters].to_h).to eq(message_id: 42, allow_sending_without_reply: true)
  end

  describe "a chat that became a supergroup" do
    let(:chat) { create(:chat, telegram_id: "-4828587211", telegram_type: "group") }
    let(:message) { chat.messages.create!(role: :assistant, content: "Ало") }

    def telegram_error(**body)
      response = instance_double(Faraday::Response, status: 400, body: { ok: false, error_code: 400, **body }.to_json)
      Telegram::Bot::Exceptions::ResponseError.new(response: response)
    end

    def upgraded_error(to: -1_004_499_357_183)
      telegram_error(description: "Bad Request: group chat was upgraded to a supergroup chat", parameters: { migrate_to_chat_id: to })
    end

    it "migrates the chat and sends to the new id" do
      calls = 0
      allow(fake_telegram).to receive(:send_message).and_wrap_original do |original, **params|
        (calls += 1) == 1 ? raise(upgraded_error) : original.call(**params)
      end

      described_class.new(chat: chat).deliver(message)

      expect(chat.reload).to have_attributes(telegram_id: "-1004499357183", telegram_type: "supergroup")
      expect(fake_telegram.sent_messages.sole).to include(chat_id: "-1004499357183", text: "Ало")
      expect(message.reload.telegram_message_id).to eq(1001)
    end

    it "sends to the new id when another process already migrated the chat" do
      Chat.find(chat.id).update!(telegram_id: "-1004499357183") # chat is now stale
      calls = 0
      allow(fake_telegram).to receive(:send_message).and_wrap_original do |original, **params|
        (calls += 1) == 1 ? raise(upgraded_error) : original.call(**params)
      end

      described_class.new(chat: chat).deliver(message)

      expect(fake_telegram.sent_messages.sole[:chat_id]).to eq("-1004499357183")
    end

    it "gives up when the chat can't be migrated, and on other errors" do
      create(:chat, telegram_id: "-1004499357183")
      allow(Rails.logger).to receive(:error)
      allow(fake_telegram).to receive(:send_message).and_raise(upgraded_error)

      expect { described_class.new(chat: chat).deliver(message) }.to raise_error(Telegram::Bot::Exceptions::ResponseError)

      allow(fake_telegram).to receive(:send_message).and_raise(telegram_error(description: "Forbidden: bot was kicked"))

      expect { described_class.new(chat: chat).deliver(message) }.to raise_error(Telegram::Bot::Exceptions::ResponseError)
      expect(chat.reload.telegram_id).to eq("-4828587211")
    end

    it "doesn't loop when Telegram keeps naming the id the chat already has" do
      chat.update!(telegram_id: "-1004499357183", telegram_type: "supergroup")
      allow(fake_telegram).to receive(:send_message).and_raise(upgraded_error)

      expect { described_class.new(chat: chat).deliver(message) }.to raise_error(Telegram::Bot::Exceptions::ResponseError)
      expect(fake_telegram).to have_received(:send_message).once
    end
  end

  it "passes a parse mode for formatted messages" do
    message = chat.messages.create!(role: :assistant, content: "<b>Ало</b>")

    described_class.new(chat: chat).deliver(message, parse_mode: "HTML")

    expect(fake_telegram.sent_messages.sole).to eq(chat_id: chat.telegram_id, text: "<b>Ало</b>", parse_mode: "HTML")
  end

  it "turns the link preview off on request" do
    message = chat.messages.create!(role: :assistant, content: "https://music.youtube.com/watch?v=a")

    described_class.new(chat: chat).deliver(message, link_preview: false)

    expect(fake_telegram.sent_messages.sole[:link_preview_options].to_h).to eq(is_disabled: true)
  end

  describe "long content" do
    let(:limit) { described_class::MAX_LENGTH }

    def deliver(content, **options)
      message = chat.messages.create!(role: :assistant, content: content)
      described_class.new(chat: chat).deliver(message, **options)
      message
    end

    def sent_texts
      fake_telegram.sent_messages.map { |params| params[:text] }
    end

    it "sends it as several messages split at blank lines, threading only the first" do
      blocks = Array.new(3) { |i| "#{i}:" + ("а" * (limit / 2)) }

      message = deliver(blocks.join("\n\n"), reply_to: 42)

      expect(sent_texts).to eq(blocks)
      expect(fake_telegram.sent_messages.map { |params| params.key?(:reply_parameters) }).to eq([ true, false, false ])
      expect(message.reload.telegram_message_id).to eq(1001)
    end

    it "keeps short blocks together in one message" do
      blocks = [ "а" * (limit / 3), "б" * (limit / 3), "в" * (limit / 2) ]

      deliver(blocks.join("\n\n"))

      expect(sent_texts).to eq([ blocks.first(2).join("\n\n"), blocks.last ])
    end

    it "splits a block too long on its own at line breaks, and a line too long by length" do
      lines = Array.new(3) { "р" * (limit / 2) }
      long_line = "д" * (limit + 10)

      deliver("#{lines.join("\n")}\n\n#{long_line}")

      expect(sent_texts).to eq([ lines[0], lines[1], lines[2], "д" * limit, "д" * 10 ])
      expect(sent_texts.map(&:length)).to all(be <= limit)
    end

    it "keeps content at the limit in one message" do
      deliver("а" * limit)

      expect(sent_texts.size).to eq(1)
    end
  end

  it "sends nothing for a blank message" do
    described_class.new(chat: chat).deliver(chat.messages.build(role: :assistant, content: ""))

    expect(fake_telegram.sent_messages).to be_empty
  end
end
