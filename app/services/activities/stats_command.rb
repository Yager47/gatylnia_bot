module Activities
  # Answers "кава за тиждень", "віджимання за місяць", "відтискання за рік", ...
  class StatsCommand
    KINDS = {
      "кава" => :coffee,
      "віджимання" => :push_ups,
      "відтискання" => :push_ups
    }.freeze

    # Period word => [Time range method, label for the reply header]
    PERIODS = {
      "сьогодні" => [ :all_day, "сьогодні" ],
      "день" => [ :all_day, "сьогодні" ],
      "тиждень" => [ :all_week, "поточний тиждень" ],
      "місяць" => [ :all_month, "поточний місяць" ],
      "рік" => [ :all_year, "поточний рік" ]
    }.freeze

    PATTERN = /\A(#{KINDS.keys.join('|')}) за (#{PERIODS.keys.join('|')})\z/

    def initialize(command:, chat:)
      @command = command
      @chat = chat
    end

    # Returns the reply text, or nil when the command isn't an activity stats
    # request. Expects the command already lowercased, without the bot mention.
    def call
      match = PATTERN.match(@command.strip)
      return unless match

      word, period = match.captures
      range_method, label = PERIODS.fetch(period)
      # Time.current is in the app time zone (Kyiv), not the server's UTC clock.
      rows = Leaderboard.new(chat: @chat, kind: KINDS.fetch(word), range: Time.current.public_send(range_method)).rows

      "#{word.capitalize} за #{label}:\n\n#{body(rows)}"
    end

    private

    def body(rows)
      return "Нікого." if rows.empty?

      rows.map { |row| "#{@chat.member_names.name(row.user)}: #{row.total}" }.join("\n")
    end
  end
end
