module Response
  class BotCommand < Response::Base
    def initialize(user:, text:, chat:)
      super(user: user, text: text)

      @chat = chat
      @command = nil
    end

    def process
      return unless @text.include?(BOT_MENTION.downcase)
      @command = @text.sub("#{BOT_MENTION.downcase} ", "")

      process_rps
      process_stat
      process_data
      process_bugging
      process_other
    end

    private

    def process_rps
      RpsGame.new(user: @user, user_weapon: @command, chat: @chat).process
    end

    def process_stat
      keyword = "гатуни за "
      return unless @command.include?(keyword)

      response = ""
      command = @command.sub(keyword, "")

      case command
      when "сьогодні", "день"
        response << "Сьогоднішні гатуни:\n\n"
        range = Date.today.beginning_of_day..Date.today.end_of_day
        response << calculate_entries(range)
      when "тиждень"
        response << "Гатуни за поточний тиждень:\n\n"
        range = Date.today.beginning_of_week.beginning_of_day..Date.today.end_of_week.end_of_day
        response << calculate_entries(range)
      when "місяць"
        response << "Гатуни за поточний місяць:\n\n"
        range = Date.today.beginning_of_month.beginning_of_day..Date.today.end_of_month.end_of_day
        response << calculate_entries(range)
      when "рік"
        response << "Гатуни за поточний рік:\n\n"
        range = Date.today.beginning_of_year.beginning_of_day..Date.today.end_of_year.end_of_day
        response << calculate_entries(range)
      end

      success(response) if response.present?
    end

    def calculate_entries(range)
      info = @chat.users.map do |user|
        entries_size = user.entries.where(chat: @chat, created_at: range).size
        next if entries_size.zero?
        [user.name, entries_size]
      end.compact

      info = info.sort { |a, b| b[1] <=> a[1] }
      info.map { |entry| "#{entry[0]}: #{entry[1]}" }.join("\n")
    end

    def process_data
      success answer(@command) if data[@command].present?
    end

    def process_bugging
      bug_user(pattern: "пошли", fee: 100)
      bug_user(pattern: "образь", fee: 150)
    end

    def bug_user(pattern:, fee:)
      pattern = "#{pattern} @"
      return unless @command.include?(pattern)

      @user.points.create!(chat: @chat, user: @user, amount: -fee, reason: @command)
      target_user = @chat.users.find_by(username: @command.sub(pattern, ""))

      if target_user
        phrases = pattern == "пошли @" ? fu_phrases : swear_phrases
        success "#{@user.first_name} за #{fee} замовив: \n\n#{mention_user_in(phrases, target_user).sample}"
      else
        success "Такої людини тут нема, але #{fee} я все одно забрав. Шоб не вмикала чєпуха."
      end
    end

    def process_other
      success answers("bot_call").sample
    end

    def mention_user_in(phrases, user)
      phrases.map { |phrase| "@#{user.username} #{phrase}" }
    end

    def balance_all
      response = "Загальний баланс в чаті: \n"

      balances = @chat.users
                      .map { |user| { name: user.name, balance: balance(user) } }
                      .sort { |a, b| b[:balance] <=> a[:balance] }

      balances.each { |b_data| response << "\n#{b_data[:name]}: #{b_data[:balance]}" }
      response
    end

    # Not used
    def balance(user)
      user.balance(@chat)
    end

    def fu_phrases
      phrases("fuck_you")
    end

    def swear_phrases
      fu_phrases + phrases("swear")
    end

    def data
      {
        "підтримай мене" => answers("support", first_name: @user.first_name),
        "дай ритм" => TimeSignature.call,
        "пошли мене" => mention_user_in(fu_phrases, @user),
        "образь мене" => mention_user_in(swear_phrases, @user),
        "пошли когось" => mention_user_in(fu_phrases, @chat.users.sample),
        "образь когось" => mention_user_in(swear_phrases, @chat.users.sample),
        "баланс" => balance_all
        # "баланс" => "Твій баланс: #{balance(@user)}"
      }
    end
  end
end
