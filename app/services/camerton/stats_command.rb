module Camerton
  # Camerton's commands in chats with it on: "топ", "дно" (optionally
  # "альбоми"/"пісні", then "за тиждень/місяць/рік"), "оцінки" in reply to a
  # shared release, "критики", "камертони", "мій смак", "смак з @нік",
  # "що послухати [альбоми|пісні] [жанр] [@нік]" and "жанри".
  class StatsCommand
    # Period word => [Time range method, label for the reply header]
    PERIODS = {
      "тиждень" => [ :all_week, "поточний тиждень" ],
      "місяць" => [ :all_month, "поточний місяць" ],
      "рік" => [ :all_year, "поточний рік" ]
    }.freeze

    KINDS = { "альбоми" => "album", "пісні" => "song" }.freeze

    RANKING = /\A(топ|дно)(?: (#{KINDS.keys.join('|')}))?(?: за (#{PERIODS.keys.join('|')}))?\z/
    TASTE_MATCH = /\Aсмак з @(\w+)\z/
    # The genre is whatever is left before an optional @нік; it can't hold
    # an @, so "що послухати rock @olya ще щось" isn't ours.
    TO_LISTEN = /\Aщо послухати(?: (#{KINDS.keys.join('|')}))?(?: ([^@]+?))?(?: @(\w+))?\z/

    def initialize(command:, chat:, user: nil, reply_to_message: nil)
      @command = command.strip
      @chat = chat
      @user = user
      @reply_to_message = reply_to_message
    end

    # Returns the reply text (a Response::Html for "що послухати"), or nil
    # when the command isn't Camerton's.
    # Expects the command already lowercased, without the bot mention.
    def call
      return unless @chat.camerton_enabled?

      if (match = RANKING.match(@command))
        ranking(*match.captures)
      elsif (match = TASTE_MATCH.match(@command))
        taste_match(match[1])
      elsif (match = TO_LISTEN.match(@command))
        to_listen(*match.captures)
      else
        case @command
        when "оцінки" then release_card
        when "критики" then Critics.new(chat: @chat).text
        when "камертони" then Sharers.new(chat: @chat).text
        when "мій смак" then Taste.new(chat: @chat, user: @user).text
        when "жанри" then Genres.new(chat: @chat).text
        end
      end
    end

    private

    def ranking(word, kind, period)
      range_method, label = PERIODS[period]
      range = Time.current.public_send(range_method) if range_method
      Ranking.new(chat: @chat, best: word == "топ", kind: KINDS[kind], range: range, label: label || "весь час").text
    end

    def taste_match(username)
      other = find_member(username)
      return "Не знайшов @#{username} у цьому чаті." unless other
      return "Із собою збіг завжди 100%." if other == @user

      TasteMatch.new(chat: @chat, user: @user, other: other).text
    end

    def to_listen(kind, genre, username)
      member = username ? find_member(username) : @user
      return "Не знайшов @#{username} у цьому чаті." unless member

      Response::Html.new(text: ToListen.new(chat: @chat, user: member, kind: KINDS[kind], genre: genre&.strip).text)
    end

    # Usernames are case-insensitive in Telegram; the command is lowercased.
    def find_member(username)
      @chat.users.find_by("LOWER(users.username) = ?", username)
    end

    def release_card
      share = RepliedShare.find(chat: @chat, reply_to_message: @reply_to_message)
      return "Відповідай цією командою на посилання з релізом або на мою відповідь під ним." unless share

      ReleaseCard.new(share).text
    end
  end
end
