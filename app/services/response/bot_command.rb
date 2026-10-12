module Response
  class BotCommand < Response::Base
    def initialize(user:, text:, chat:)
      super(user: user, text: text)

      @chat = chat
      @command = nil
    end

    def call
      return unless @text.include?(BotMention.text)
      @command = @text.sub("#{BotMention.text} ", "")

      process_mode || mode_reply
    end

    private

    # The first command that answers wins, in this order.
    def mode_reply
      case @chat.mode
      when "default"
        process_rps || process_stat || process_activity_stats || process_data || process_bugging
      when "accountant"
        process_data
      end
    end

    def process_rps
      RpsGame.new(user: @user, user_weapon: @command, chat: @chat).call
    end

    def process_mode
      keyword = "режим: "
      return unless @command.include?(keyword)

      response = ""
      command = @command.sub(keyword, "")

      case command
      when "звичайний", "дефолт", "дефолтний"
        if @chat.mode == "default"
          response << "Я вже на звичайному режимі."
        else
          @chat.update!(mode: "default")
          response << "Активовано звичайний режим."
        end
      when "бухгалтер", "бухгалтерський"
        if @chat.mode == "accountant"
          response << "Я вже на бухгалтерському режимі."
        else
          @chat.update!(mode: "accountant")
          response << "Активовано бухгалтерський режим."
        end
      when "київський", "киівський"
        response << "Слава Київському режиму!"
      else
        response << "Нема такого режиму."
      end

      reply(response) if response.present?
    end

    def process_stat
      keyword = "гатуни за "
      return unless @command.include?(keyword)

      response = ""
      command = @command.sub(keyword, "")

      case command
      # Time.current is in the app time zone (Kyiv); Date.today would use the
      # server clock, which is UTC in production.
      when "сьогодні", "день"
        response << "Сьогоднішні гатуни:\n\n"
        response << calculate_entries(Time.current.all_day)
      when "тиждень"
        response << "Гатуни за поточний тиждень:\n\n"
        response << calculate_entries(Time.current.all_week)
      when "місяць"
        response << "Гатуни за поточний місяць:\n\n"
        response << calculate_entries(Time.current.all_month)
      when "рік"
        response << "Гатуни за поточний рік:\n\n"
        response << calculate_entries(Time.current.all_year)
      end

      reply(response) if response.present?
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
      bug_user(pattern: "пошли", fee: 100) || bug_user(pattern: "образь", fee: 150)
    end

    def bug_user(pattern:, fee:)
      pattern = "#{pattern} @"
      return unless @command.include?(pattern)

      @user.points.create!(chat: @chat, user: @user, amount: -fee, reason: @command)
      target_user = @chat.users.find_by(username: @command.sub(pattern, ""))

      if target_user
        phrases = pattern == "пошли @" ? fu_phrases : swear_phrases
        reply("#{@user.first_name} за #{fee} замовив: \n\n#{mention_user_in(phrases, target_user).sample}")
      else
        reply("Такої людини тут нема, але #{fee} я все одно забрав. Шоб не вмикала чєпуха.")
      end
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

      "Загальний баланс в чаті: \n" + lines.map { |name, balance| "\n#{name}: #{balance}" }.join
    end

    def fu_phrases
      phrases("fuck_you")
    end

    def swear_phrases
      fu_phrases + phrases("swear")
    end

    def data
      case @chat.mode
      when "default" then default_data
      when "accountant" then accountant_data
      end
    end

    def default_data
      {
        "підтримай мене" => -> { answers("support", first_name: @user.first_name) },
        "дай ритм" => -> { TimeSignature.call },
        "пошли мене" => -> { mention_user_in(fu_phrases, @user) },
        "образь мене" => -> { mention_user_in(swear_phrases, @user) },
        "пошли когось" => -> { mention_user_in(fu_phrases, @chat.users.sample) },
        "образь когось" => -> { mention_user_in(swear_phrases, @chat.users.sample) },
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
