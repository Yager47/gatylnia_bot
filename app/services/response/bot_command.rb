module Response
  # "@bot <command>": commands addressed to the bot at the start of a message.
  class BotCommand
    include Responder

    MODE_PREFIX = "режим: ".freeze
    CAMERTON_PREFIX = "камертон: ".freeze
    NOTES_PREFIX = "замітки: ".freeze
    HELP = %w[рятуй help].freeze
    STATS_PREFIX = "гатуни за ".freeze

    # Period word => [Time range method, reply header]
    STATS_PERIODS = {
      "сьогодні" => [ :all_day, "Сьогоднішні гатуни" ],
      "день" => [ :all_day, "Сьогоднішні гатуни" ],
      "тиждень" => [ :all_week, "Гатуни за поточний тиждень" ],
      "місяць" => [ :all_month, "Гатуни за поточний місяць" ],
      "рік" => [ :all_year, "Гатуни за поточний рік" ]
    }.freeze

    # "пошли @username": the author pays the fee whether or not the target is
    # in the chat, if their balance covers it. Prefix => [fee, phrase list
    # method]. "образь @username" is written by the AI (AiOrder).
    BUGGING = {
      "пошли @" => [ 100, :fu_phrases ]
    }.freeze

    # reply_to_message: the Telegram message the command replied to, if any
    # (Camerton's "оцінки" is about the release in it).
    def initialize(user:, text:, chat:, reply_to_message: nil)
      @user = user
      @chat = chat
      @reply_to_message = reply_to_message
      # nil unless the text starts with the mention followed by a command.
      @command = text[/\A#{Regexp.escape(BotMention.text)}\s+(.+)/m, 1]
    end

    def call
      return unless @command

      process_help || process_mode || process_camerton || process_notes_toggle || process_notes || process_camerton_stats || mode_reply
    end

    private

    # The first command that answers wins, in this order.
    def mode_reply
      if @chat.default?
        process_rps || process_stat || process_activity_stats || process_ai_order || process_data || process_bugging
      elsif @chat.accountant?
        process_data
      end
    end

    def process_rps
      RpsGame.new(user: @user, user_weapon: @command, chat: @chat).call
    end

    def process_ai_order
      AiOrder.new(user: @user, command: @command, chat: @chat).call
    end

    # Every mode.
    def process_help
      Html.new(text: Help.new(chat: @chat).text) if HELP.include?(@command.strip)
    end

    def process_mode
      return unless @command.start_with?(MODE_PREFIX)

      text =
        case @command.delete_prefix(MODE_PREFIX)
        when "звичайний", "дефолт", "дефолтний"
          switch_mode("default", already: "Я вже на звичайному режимі.", switched: "Активовано звичайний режим.")
        when "бухгалтер", "бухгалтерський"
          switch_mode("accountant", already: "Я вже на бухгалтерському режимі.", switched: "Активовано бухгалтерський режим.")
        when "тихий"
          switch_mode("quiet", already: "Я вже на тихому режимі.", switched: "Активовано тихий режим. Відповідаю лише на команди.")
        when "київський", "киівський"
          "Слава Київському режиму!"
        else
          "Нема такого режиму."
        end

      reply(text)
    end

    def switch_mode(mode, already:, switched:)
      return already if @chat.mode == mode

      @chat.update!(mode: mode)
      switched
    end

    # Works in every mode: Camerton runs alongside whatever the mode is.
    def process_camerton
      return unless @command.start_with?(CAMERTON_PREFIX)

      text =
        case @command.delete_prefix(CAMERTON_PREFIX)
        when "увімкни", "вкл"
          switch_camerton(true, already: "Камертон вже увімкнений.", switched: "Камертон увімкнено.")
        when "вимкни", "викл"
          switch_camerton(false, already: "Камертон вже вимкнений.", switched: "Камертон вимкнено.")
        else
          "Камертон: увімкни або вимкни?"
        end

      reply(text)
    end

    # Works in every mode, like Camerton: notes on demo tracks sent as audio.
    def process_notes_toggle
      return unless @command.start_with?(NOTES_PREFIX)

      text =
        case @command.delete_prefix(NOTES_PREFIX)
        when "увімкни", "вкл"
          switch_notes(true, already: "Замітки вже увімкнені.", switched: "Замітки увімкнено.")
        when "вимкни", "викл"
          switch_notes(false, already: "Замітки вже вимкнені.", switched: "Замітки вимкнено.")
        else
          "Замітки: увімкни або вимкни?"
        end

      reply(text)
    end

    # Every mode, when notes are on in the chat.
    def process_notes
      text = Notes::Command.new(command: @command, chat: @chat, user: @user, reply_to_message: @reply_to_message).call
      reply(text) if text
    end

    def switch_notes(enabled, already:, switched:)
      return already if @chat.notes_enabled == enabled

      @chat.update!(notes_enabled: enabled)
      switched
    end

    # Every mode, when Camerton is on in the chat.
    def process_camerton_stats
      text = Camerton::StatsCommand.new(command: @command, chat: @chat, user: @user, reply_to_message: @reply_to_message).call
      reply(text) if text
    end

    def switch_camerton(enabled, already:, switched:)
      return already if @chat.camerton_enabled == enabled

      @chat.update!(camerton_enabled: enabled)
      switched
    end

    # Time.current is in the app time zone (Kyiv); Date.today would use the
    # server clock, which is UTC in production.
    def process_stat
      return unless @command.start_with?(STATS_PREFIX)

      range, header = STATS_PERIODS[@command.delete_prefix(STATS_PREFIX)]
      return unless range

      reply("#{header}:\n\n#{calculate_entries(Time.current.public_send(range))}")
    end

    def process_activity_stats
      stats = Activities::StatsCommand.new(command: @command, chat: @chat).call
      reply(stats) if stats
    end

    # Two queries no matter how many users the chat has: one grouped count,
    # one to load the names of users who have entries.
    def calculate_entries(range)
      counts = @chat.entries.where(created_at: range).group(:user_id).count
      users = User.where(id: counts.keys).index_by(&:id)

      counts.sort_by { |_user_id, count| -count }
            .map { |user_id, count| "#{users[user_id].name}: #{count}" }
            .join("\n")
    end

    # Only the matching command's reply is built: a mention that isn't a
    # command loads no YAML and runs no queries here.
    def process_data
      build_reply = data[@command]
      return unless build_reply

      text = pick(build_reply.call)
      reply(text) if text.present?
    end

    def process_bugging
      prefix, (fee, phrase_list) = BUGGING.find { |prefix, _| @command.start_with?(prefix) }
      return unless prefix

      return reply(Zhmykhcoins.not_enough(@user, @chat, fee)) unless Zhmykhcoins.spend(@user, @chat, fee, reason: @command)

      # The command arrives lowercased; usernames are stored as written.
      target_user = @chat.users.find_by("LOWER(users.username) = ?", @command.delete_prefix(prefix))
      return reply("Такої людини тут нема, але #{Zhmykhcoins.count(fee)} я все одно забрав. Шоб не вмикала чєпуха.") unless target_user

      reply("#{@user.first_name} за #{Zhmykhcoins.count(fee)} замовив: \n\n#{pick(mention_user_in(send(phrase_list), target_user))}")
    end

    def mention_user_in(phrases, user)
      phrases.map { |phrase| "@#{user.username} #{phrase}" }
    end

    # Two queries however many members the chat has: one grouped SUM, one to
    # load the members. Members without points show 0.
    def balance_all
      totals = @chat.points.group(:user_id).sum(:amount)
      lines = @chat.users
                   .map { |user| [ user.name, totals.fetch(user.id, 0) ] }
                   .sort_by { |name, balance| [ -balance, name ] }

      "Баланс жмихкоїнів у чаті: \n" + lines.map { |name, balance| "\n#{name}: #{balance}" }.join
    end

    def data
      if @chat.default?
        default_data
      elsif @chat.accountant?
        accountant_data
      end
    end

    def default_data
      {
        "підтримай мене" => -> { render_answers("support", first_name: @user.first_name) },
        "дай ритм" => -> { TimeSignature.call },
        "пошли мене" => -> { mention_user_in(fu_phrases, @user) },
        "образь мене" => -> { mention_user_in(swear_phrases, @user) },
        "пошли когось" => -> { mention_user_in(fu_phrases, @chat.users.sample) },
        "баланс" => -> { balance_all }
      }
    end

    def accountant_data
      {
        "баланс" => -> { balance_all }
      }
    end
  end
end
