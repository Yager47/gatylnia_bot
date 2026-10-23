require "erb"

module Response
  # "@bot рятуй" / "@bot help": the commands that work in this chat right
  # now, for its mode and with Camerton on or off. When adding a command to
  # BotCommand, add it here too (spec/services/response/help_spec.rb checks).
  # Telegram HTML: a bullet per line, commands in bold.
  class Help
    MODE_NAMES = { "default" => "звичайний", "accountant" => "бухгалтер", "quiet" => "тихий" }.freeze
    # For the removals the AI reads (Response::Removal): any wording works.
    SIMILAR = "або щось подібне".freeze

    def initialize(chat:)
      @chat = chat
    end

    def text
      sections = [
        "Що я вмію (режим: #{MODE_NAMES.fetch(@chat.mode)}):",
        mode_section,
        camerton_section,
        notes_section,
        settings_section
      ]

      sections.compact.join("\n\n")
    end

    private

    def mode_section
      lines =
        case @chat.mode
        when "default" then default_lines
        when "accountant" then [ give_line, limit_line, command("#{bot} баланс", "жмихкоїни всіх у чаті"), summary_line, *pseudonym_lines ]
        when "quiet" then [ fact("Тут я мовчу і відповідаю лише на команди.") ]
        end

      lines.join("\n")
    end

    def default_lines
      [
        command("#{bot} підтримай мене", "скажу щось підбадьорливе"),
        command("#{bot} дай ритм", "випадковий розмір такту"),
        command("#{bot} пошли мене / образь мене", "пошлю чи ображу тебе"),
        command("#{bot} пошли когось", "пошлю випадкового учасника"),
        command("#{bot} пошли @нік", "когось конкретного, за 100 жмихкоїнів, якщо вони в тебе є"),
        command("#{bot} образь когось / образь @нік", "ШІ обісре випадкового чи конкретного учасника, за #{AiOrder::ROAST_FEE} жмихкоїнів, якщо вони в тебе є"),
        command("#{bot} анекдот [про …]", "ШІ розкаже анекдот (маткор, гатіння, нерівні розміри…), за #{AiOrder::ANECDOTE_FEE} жмихкоїнів"),
        command("#{bot} камінь / ножиці / папір", "зіграємо на 10 жмихкоїнів"),
        give_line,
        limit_line,
        command("#{bot} баланс", "жмихкоїни всіх у чаті"),
        summary_line,
        *pseudonym_lines,
        fact("За каву плачу жмихкоїнами: 1–2 чашки +25, 3–4 +10, з пʼятої −10; за підхід відтискань +100, до трьох на день"),
        command("#{bot} гатуни за сьогодні|тиждень|місяць|рік", "хто скільки гатив"),
        command("#{bot} кава за … / віджимання за …", "те саме для кави й віджимань"),
        command("#{bot} видали останню каву / прибери гатіння", "приберу твій останній запис; віджимання не видаляються", hint: SIMILAR),
        command("видали каву / видали гатіння", "те саме, без мене"),
        command("#{bot} <що завгодно>", "просто поговоримо")
      ]
    end

    def give_line
      command("+200 / -100", "дати чи забрати жмихкоїни, до #{Reply::DAILY_BUDGET} на день; число без знака не рахується", hint: "відповіддю на повідомлення")
    end

    def limit_line
      command("#{bot} мій ліміт / ліміт", "скільки ще можеш дати чи забрати сьогодні")
    end

    def pseudonym_lines
      [
        command("#{bot} псевдонім <імʼя>", "моє імʼя для тебе в цьому чаті, до #{ChatUser::MAX_PSEUDONYM} символів, за #{Pseudonym::FEE} жмихкоїнів"),
        command("#{bot} мій псевдонім / прибери псевдонім", "показати чи безкоштовно прибрати")
      ]
    end

    def summary_line
      fact("Щопонеділка о 10:00 підсумок жмихкоїнів за тиждень")
    end

    def camerton_section
      return unless @chat.camerton_enabled?

      [
        "Камертон 🎵:",
        fact("Посилання з music.youtube.com — запишу пісню чи альбом"),
        fact("Відповідь на нього текстом, голосовим чи кружечком — твоя оцінка 1–10"),
        command("#{bot} видали мою оцінку", "приберу твою оцінку цього релізу", hint: "#{SIMILAR}, відповіддю на реліз"),
        command("#{bot} топ / дно [альбоми|пісні] [за тиждень|місяць|рік]", "найкращі й найгірші релізи"),
        command("#{bot} оцінки", "хто як його оцінив", hint: "відповіддю на реліз"),
        fact("Щодня о 09:00 нагадую, хто ще не оцінив релізи за останній тиждень"),
        command(
          "#{bot} що (шо) послухати [альбоми|пісні] [жанр] [@нік]",
          "10 останніх релізів, які ти (чи хтось) ще не оцінив; жанр англійською, як на Discogs (rock, jazz, shoegaze)"
        ),
        command("#{bot} жанри", "жанри й стилі наших релізів, від найпопулярніших"),
        command("#{bot} критики", "хто скільки оцінив і наскільки суворо"),
        command("#{bot} камертони", "чиї релізи заходять найкраще"),
        command("#{bot} мій смак", "твої оцінки, улюблене й найближчий смак"),
        command("#{bot} смак з @нік", "наскільки ваші оцінки збігаються"),
        command("#{bot} ачівки / досягнення", "усі ачівки й скільки людей їх здобули"),
        command("#{bot} мої ачівки / мої досягнення", "твої ачівки й скільки лишилось до наступних")
      ].join("\n")
    end

    def notes_section
      return unless @chat.notes_enabled?

      [
        "Замітки 📝:",
        fact("Аудіо (mp3 чи файлом wav/flac) — запишу як версію треку"),
        fact("Відповідь на нього текстом, голосовим чи кружечком — твоя замітка"),
        command("#{bot} замітки", "всі замітки до нього, по людях", hint: "відповіддю на аудіо"),
        command("#{bot} замітки @нік / мої замітки", "замітки однієї людини", hint: "відповіддю на аудіо"),
        command("#{bot} видали замітки", "прибрати свої замітки до нього", hint: "відповіддю на аудіо"),
        command("#{bot} останнє аудіо / #{bot} аудіо", "покажу, де останній трек")
      ].join("\n")
    end

    def settings_section
      [
        "Налаштування:",
        command("#{bot} режим: звичайний|бухгалтер|тихий"),
        command("#{bot} камертон: увімкни|вимкни", "оцінювання музики (зараз #{@chat.camerton_enabled? ? 'увімкнене' : 'вимкнене'})"),
        command("#{bot} замітки: увімкни|вимкни", "замітки до наших треків (зараз #{@chat.notes_enabled? ? 'увімкнені' : 'вимкнені'})"),
        command("#{bot} рятуй / help", "цей список"),
        command("/ping", "перевірити, чи я живий")
      ].join("\n")
    end

    # "• <b>@bot оцінки</b> (відповіддю на реліз) — хто як його оцінив"
    def command(text, description = nil, hint: nil)
      line = "• <b>#{escape(text)}</b>"
      line += " (#{escape(hint)})" if hint
      line += " — #{escape(description)}" if description
      line
    end

    # Something I do on my own, not a command; written as a sentence.
    def fact(text)
      "• #{escape(text)}"
    end

    def escape(text)
      ERB::Util.html_escape(text)
    end

    def bot
      BotMention.text
    end
  end
end
