class BotCommand
  def initialize(bot:, chat:, command:)
    @bot = bot
    @chat = chat
    @command = command.strip
  end

  def call
    return if @command.blank?
    response = ""

    case @command
    when "сьогодні", "день"
      response << "Сьогоднішні гатуни:\n\n"
      range = Date.today.beginning_of_day..Date.today.end_of_day
      response << stat(range)
    when "тиждень"
      response << "Гатуни за поточний тиждень:\n\n"
      range = Date.today.beginning_of_week.beginning_of_day..Date.today.end_of_week.end_of_day
      response << stat(range)
    when "місяць"
      response << "Гатуни за поточний місяць:\n\n"
      range = Date.today.beginning_of_month.beginning_of_day..Date.today.end_of_month.end_of_day
      response << stat(range)
    when "рік"
      response << "Гатуни за поточний рік:\n\n"
      range = Date.today.beginning_of_year.beginning_of_day..Date.today.end_of_year.end_of_day
      response << stat(range)
    end

    send_to_chat(response) if response.present?
  end

  private

  def stat(range)
    info = @chat.users.map do |user|
      entries_size = user.entries.where(chat: @chat, created_at: range).size
      next if entries_size.zero?
      [user.name, entries_size]
    end.compact

    info = info.sort { |a, b| b[1] <=> a[1] }
    info.map { |entry| "#{entry[0]}: #{entry[1]}" }.join("\n")
  end

  def send_to_chat(text)
    @bot.api.send_message(chat_id: @chat.telegram_id, text: text)
  end
end