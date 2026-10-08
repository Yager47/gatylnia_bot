# Stands in for Telegram::Bot::Client in specs. Records every API call instead
# of making HTTP requests, and returns objects shaped like the real responses
# (send_message returns something with #message_id).
class FakeTelegramClient
  SentMessage = Struct.new(:message_id, keyword_init: true)

  attr_reader :sent_messages

  def initialize
    @sent_messages = []
    @next_message_id = 1000
  end

  def api
    self
  end

  def send_message(**params)
    @sent_messages << params
    @next_message_id += 1
    SentMessage.new(message_id: @next_message_id)
  end
end

RSpec.configure do |config|
  config.before do
    @fake_telegram = FakeTelegramClient.new
    allow(TelegramClient).to receive(:build).and_return(@fake_telegram)

    # Fail loudly if a spec reaches OpenAI without stubbing it explicitly.
    allow(Ai).to receive(:reply_in).and_raise("Unstubbed Ai.reply_in call in spec")
  end
end

module FakeTelegramClientHelper
  def fake_telegram
    @fake_telegram
  end
end

RSpec.configure { |config| config.include FakeTelegramClientHelper }
