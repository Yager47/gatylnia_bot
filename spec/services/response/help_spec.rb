require "rails_helper"

RSpec.describe Response::Help do
  let(:chat) { create(:chat, mode: :default) }
  let(:user) { create(:user, chats: [ chat ]) }

  def help
    described_class.new(chat: chat).text
  end

  def ask(text)
    Response::BotCommand.new(user: user, chat: chat, text: text).call
  end

  it "answers рятуй and help in every mode" do
    Chat.modes.each_key do |mode|
      chat.update!(mode: mode)

      expect(ask("@test_bot рятуй")).to eq(help)
      expect(ask("@test_bot help")).to eq(help)
    end
  end

  it "names the current mode" do
    expect(help).to start_with("Що я вмію (режим: звичайний):")
    chat.update!(mode: :quiet)
    expect(help).to start_with("Що я вмію (режим: тихий):")
  end

  # The help is written by hand: these fail when BotCommand gains a command
  # the help doesn't mention.
  it "lists every default-mode command" do
    command = Response::BotCommand.new(user: user, chat: chat, text: "@test_bot рятуй")
    phrases = command.send(:default_data).keys + Response::RpsGame::WEAPONS + %w[пошли\ @ образь\ @ гатуни\ за кава\ за віджимання\ за]

    phrases.each { |phrase| expect(help).to include(phrase), phrase }
  end

  it "lists only баланс in accountant mode" do
    chat.update!(mode: :accountant)
    command = Response::BotCommand.new(user: user, chat: chat, text: "@test_bot рятуй")

    command.send(:accountant_data).each_key { |phrase| expect(help).to include("@test_bot #{phrase}") }
    expect(help).not_to include("підтримай мене", "камінь")
  end

  it "lists no mode commands in quiet mode" do
    chat.update!(mode: :quiet)

    expect(help).to include("відповідаю лише на команди")
    expect(help).not_to include("баланс")
  end

  it "lists Camerton's commands only when it's on, and always how to switch it" do
    expect(help).not_to include("@test_bot топ")
    expect(help).to include("@test_bot камертон: увімкни|вимкни — оцінювання музики (зараз вимкнене)")

    chat.update!(camerton_enabled: true)

    expect(help).to include(
      "@test_bot топ / дно", "@test_bot оцінки", "@test_bot критики", "@test_bot камертони",
      "@test_bot мій смак", "@test_bot смак з @нік", "щодня о 09:00 нагадую", "(зараз увімкнене)"
    )
  end

  it "lists the notes commands only when they're on" do
    expect(help).not_to include("@test_bot замітки (відповіддю на аудіо)")

    chat.update!(notes_enabled: true)

    expect(help).to include(
      "Замітки 📝:", "текстом, голосовим чи кружечком — твоя замітка", "@test_bot замітки (відповіддю на аудіо)", "@test_bot замітки @нік / мої замітки", "@test_bot видали замітки",
      "@test_bot останнє аудіо або @test_bot аудіо"
    )
  end

  it "always says how to switch notes, with their state" do
    expect(help).to include("@test_bot замітки: увімкни|вимкни — замітки до наших треків (зараз вимкнені)")

    chat.update!(notes_enabled: true)

    expect(help).to include("(зараз увімкнені)")
  end

  it "lists every mode name and the settings commands" do
    described_class::MODE_NAMES.each_value { |name| expect(help).to include(name) }
    expect(Chat.modes.keys).to match_array(described_class::MODE_NAMES.keys)
    expect(help).to include("@test_bot режим:", "@test_bot рятуй або help", "/ping")
  end
end
