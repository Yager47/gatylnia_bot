module Response
  # "@bot псевдонім Сер Гатило": a name of your own in this chat for FEE
  # жмихкоїнів, shown in the bot's replies instead of your Telegram name
  # (MemberNames). Each change costs FEE, refused unless the balance covers
  # it. "@bot мій псевдонім" shows it; "@bot прибери псевдонім" (or
  # "видали") drops it for free. Reads the original text, so the pseudonym
  # keeps its case.
  class Pseudonym
    include Responder

    FEE = 500
    SET = "псевдонім".freeze
    SHOW = "мій псевдонім".freeze
    REMOVE = [ "прибери псевдонім", "видали псевдонім" ].freeze
    TAKEN = "Цей псевдонім тут уже зайнятий.".freeze

    def initialize(user:, chat:, text:)
      @user = user
      @chat = chat
      # nil unless the text starts with the mention followed by a command.
      @command = text.to_s[/\A#{Regexp.escape(BotMention.text)}\s+(.+)/im, 1]&.squish
    end

    def call
      return unless @command

      command = @command.downcase
      if command == SHOW
        show
      elsif REMOVE.include?(command)
        remove
      elsif command == SET
        reply("Напиши, який: #{BotMention.text} #{SET} Сер Гатило. Коштує #{Zhmykhcoins.count(FEE)}.")
      elsif command.start_with?("#{SET} ")
        buy(@command[SET.length..])
      end
    end

    private

    def show
      pseudonym = membership.pseudonym
      return reply("Твій псевдонім тут: #{pseudonym}") if pseudonym

      reply("Псевдоніма нема, ти тут #{@user.name}. Купити: #{BotMention.text} #{SET} …, #{Zhmykhcoins.count(FEE)}.")
    end

    def remove
      chat_user = membership
      return reply("У тебе й так нема псевдоніма.") unless chat_user.pseudonym

      chat_user.update!(pseudonym: nil)
      reply("Псевдонім прибрано, ти знову #{@user.name}.")
    end

    # Validated before charging; the unique index catches a race with someone
    # taking the same name at the same moment. The savepoint keeps that from
    # breaking the update's transaction, and rolls the fee back with it.
    def buy(name)
      chat_user = membership
      chat_user.pseudonym = name
      return reply("Це вже твій псевдонім.") unless chat_user.pseudonym_changed?
      return reply(invalid(chat_user)) unless chat_user.valid?

      ChatUser.transaction(requires_new: true) do
        next reply(Zhmykhcoins.not_enough(@user, @chat, FEE)) unless Zhmykhcoins.spend(@user, @chat, FEE, reason: "Псевдонім: #{chat_user.pseudonym}")

        chat_user.save!
        reply("Тепер ти тут #{chat_user.pseudonym}. Це коштувало #{Zhmykhcoins.count(FEE)}.")
      end
    rescue ActiveRecord::RecordNotUnique
      reply(TAKEN)
    end

    def invalid(chat_user)
      chat_user.errors.of_kind?(:pseudonym_key, :taken) ? TAKEN : "Псевдонім до #{ChatUser::MAX_PSEUDONYM} символів."
    end

    def membership
      @chat.chat_users.find_or_create_by!(user: @user)
    end
  end
end
