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

      expect(ask("@test_bot рятуй")).to eq(Response::Html.new(text: help))
      expect(ask("@test_bot help")).to eq(Response::Html.new(text: help))
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
    phrases = command.send(:default_data).keys + Response::RpsGame::WEAPONS + %w[пошли\ @ образь\ @ образь\ когось анекдот гатуни\ за кава\ за віджимання\ за]

    phrases.each { |phrase| expect(help).to include(phrase), phrase }
  end

  it "says how to remove a coffee or a gato" do
    expect(help).to include("<b>@test_bot видали останню каву / прибери гатіння</b> (або щось подібне) —", "<b>видали каву / видали гатіння</b> —")
  end

  it "puts each line under a bullet, commands in bold and descriptions capitalized" do
    chat.update!(camerton_enabled: true, notes_enabled: true)
    lines = help.lines(chomp: true).reject { |line| line.empty? || line.end_with?(":") }

    lines.each { |line| expect(line).to match(/\A• (<b>|\p{Lu})/), line }
    expect(help).to include("• <b>@test_bot оцінки</b> (відповіддю на реліз) — хто як його оцінив")
    expect(help).to include("• Посилання з music.youtube.com — запишу пісню чи альбом")
  end

  it "escapes HTML in the text" do
    expect(help).to include("<b>@test_bot &lt;що завгодно&gt;</b>")
  end

  it "lists only баланс in accountant mode" do
    chat.update!(mode: :accountant)
    command = Response::BotCommand.new(user: user, chat: chat, text: "@test_bot рятуй")

    command.send(:accountant_data).each_key { |phrase| expect(help).to include(phrase) }
    expect(help).to include("<b>@test_bot баланс</b>", "<b>@test_bot мій ліміт / ліміт</b>")
    expect(help).not_to include("підтримай мене", "камінь")
  end

  it "says how to give жмихкоїни in default and accountant modes" do
    line = "• <b>+200 / -100</b> (відповіддю на повідомлення) — дати чи забрати жмихкоїни, до 500 на день; число без знака не рахується"
    expect(help).to include(line)

    chat.update!(mode: :accountant)
    expect(help).to include(line)
  end

  it "mentions the activity rewards in default mode and the weekly summary in both modes" do
    expect(help).to include("• За каву плачу жмихкоїнами", "• Щопонеділка о 10:00 підсумок жмихкоїнів за тиждень")

    chat.update!(mode: :accountant)
    expect(help).to include("Щопонеділка о 10:00")
    expect(help).not_to include("За каву")
  end

  it "says how to buy, show and remove a pseudonym in default and accountant modes" do
    lines = [ "<b>@test_bot псевдонім &lt;імʼя&gt;</b> — моє імʼя для тебе в цьому чаті, до 32 символів, за 500 жмихкоїнів",
              "<b>@test_bot мій псевдонім / прибери псевдонім</b>" ]
    expect(help).to include(*lines)

    chat.update!(mode: :accountant)
    expect(help).to include(*lines)
  end

  it "lists no mode commands in quiet mode" do
    chat.update!(mode: :quiet)

    expect(help).to include("відповідаю лише на команди")
    expect(help).not_to include("баланс")
  end

  it "lists Camerton's commands only when it's on, and always how to switch it" do
    expect(help).not_to include("@test_bot топ")
    expect(help).to include("<b>@test_bot камертон: увімкни|вимкни</b> — оцінювання музики (зараз вимкнене)")

    chat.update!(camerton_enabled: true)

    expect(help).to include(
      "@test_bot топ / дно", "@test_bot оцінки", "@test_bot критики", "@test_bot камертони",
      "@test_bot мій смак", "@test_bot смак з @нік", "Щодня о 09:00 нагадую", "(зараз увімкнене)",
      "<b>@test_bot видали мою оцінку</b> (або щось подібне, відповіддю на реліз)", "<b>@test_bot жанри</b>",
      "<b>@test_bot ачівки / досягнення</b>", "<b>@test_bot мої ачівки / мої досягнення</b>"
    )
  end

  it "lists the notes commands only when they're on" do
    expect(help).not_to include("<b>@test_bot замітки</b> (відповіддю на аудіо)")

    chat.update!(notes_enabled: true)

    expect(help).to include(
      "Замітки 📝:", "текстом, голосовим чи кружечком — твоя замітка", "<b>@test_bot замітки</b> (відповіддю на аудіо)", "@test_bot замітки @нік / мої замітки", "@test_bot видали замітки",
      "@test_bot останнє аудіо / @test_bot аудіо"
    )
  end

  it "always says how to switch notes, with their state" do
    expect(help).to include("<b>@test_bot замітки: увімкни|вимкни</b> — замітки до наших треків (зараз вимкнені)")

    chat.update!(notes_enabled: true)

    expect(help).to include("(зараз увімкнені)")
  end

  it "lists every mode name and the settings commands" do
    described_class::MODE_NAMES.each_value { |name| expect(help).to include(name) }
    expect(Chat.modes.keys).to match_array(described_class::MODE_NAMES.keys)
    expect(help).to include("@test_bot режим:", "<b>@test_bot рятуй / help</b>", "<b>/ping</b>")
  end
end
