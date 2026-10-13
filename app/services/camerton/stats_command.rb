module Camerton
  # Camerton's commands in chats with it on: "топ", "дно" (optionally "за
  # тиждень/місяць/рік") and "оцінки" in reply to a shared release.
  class StatsCommand
    # Period word => [Time range method, label for the reply header]
    PERIODS = {
      "тиждень" => [ :all_week, "поточний тиждень" ],
      "місяць" => [ :all_month, "поточний місяць" ],
      "рік" => [ :all_year, "поточний рік" ]
    }.freeze

    RANKING = /\A(топ|дно)(?: за (#{PERIODS.keys.join('|')}))?\z/

    def initialize(command:, chat:, reply_to_message: nil)
      @command = command.strip
      @chat = chat
      @reply_to_message = reply_to_message
    end

    # Returns the reply text, or nil when the command isn't Camerton's.
    # Expects the command already lowercased, without the bot mention.
    def call
      return unless @chat.camerton_enabled?

      if (match = RANKING.match(@command))
        ranking(*match.captures)
      elsif @command == "оцінки"
        release_card
      end
    end

    private

    def ranking(word, period)
      range_method, label = PERIODS[period]
      range = Time.current.public_send(range_method) if range_method
      Ranking.new(chat: @chat, best: word == "топ", range: range, label: label || "весь час").text
    end

    def release_card
      replied_id = @reply_to_message&.dig(:message_id)
      share = @chat.release_shares.replied_to(replied_id).first if replied_id
      return "Відповідай цією командою на посилання з релізом або на мою відповідь під ним." unless share

      ReleaseCard.new(share).text
    end
  end
end
