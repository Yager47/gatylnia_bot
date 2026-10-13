module Response
  # "@bot рятуй" / "@bot help": the commands that work in this chat right
  # now, for its mode and with Camerton on or off. When adding a command to
  # BotCommand, add it here too (spec/services/response/help_spec.rb checks).
  class Help
    MODE_NAMES = { "default" => "звичайний", "accountant" => "бухгалтер", "quiet" => "тихий" }.freeze

    def initialize(chat:)
      @chat = chat
    end

    def text
      sections = [
        "Що я вмію (режим: #{MODE_NAMES.fetch(@chat.mode)}):",
        mode_section,
        camerton_section,
        settings_section
      ]

      sections.compact.join("\n\n")
    end

    private

    def mode_section
      lines =
        case @chat.mode
        when "default" then default_lines
        when "accountant" then [ "#{bot} баланс — бали всіх у чаті" ]
        when "quiet" then [ "Тут я мовчу і відповідаю лише на команди." ]
        end

      lines.join("\n")
    end

    def default_lines
      [
        "#{bot} підтримай мене — скажу щось підбадьорливе",
        "#{bot} дай ритм — випадковий розмір такту",
        "#{bot} пошли мене / образь мене — пошлю чи ображу тебе",
        "#{bot} пошли когось / образь когось — випадкового учасника",
        "#{bot} пошли @нік / образь @нік — когось конкретного, за 100 / 150 балів",
        "#{bot} камінь / ножиці / папір — зіграємо на 10 балів",
        "#{bot} баланс — бали всіх у чаті",
        "#{bot} гатуни за сьогодні|тиждень|місяць|рік — хто скільки гатив",
        "#{bot} кава за … / віджимання за … — те саме для кави й віджимань",
        "#{bot} <що завгодно> — просто поговоримо"
      ]
    end

    def camerton_section
      return unless @chat.camerton_enabled?

      [
        "Камертон 🎵:",
        "посилання з music.youtube.com — запишу пісню чи альбом",
        "відповідь на нього текстом, голосовим чи кружечком — твоя оцінка 1–10",
        "#{bot} топ / дно [за тиждень|місяць|рік] — найкращі й найгірші релізи",
        "#{bot} оцінки (відповіддю на реліз) — хто як його оцінив",
        "#{bot} критики — хто скільки оцінив і наскільки суворо",
        "#{bot} камертони — чиї релізи заходять найкраще",
        "#{bot} мій смак — твої оцінки, улюблене й найближчий смак",
        "#{bot} смак з @нік — наскільки ваші оцінки збігаються"
      ].join("\n")
    end

    def settings_section
      [
        "Налаштування:",
        "#{bot} режим: звичайний|бухгалтер|тихий",
        "#{bot} камертон: увімкни|вимкни — оцінювання музики (зараз #{@chat.camerton_enabled? ? 'увімкнене' : 'вимкнене'})",
        "#{bot} рятуй або help — цей список",
        "/ping — перевірити, чи я живий"
      ].join("\n")
    end

    def bot
      BotMention.text
    end
  end
end
