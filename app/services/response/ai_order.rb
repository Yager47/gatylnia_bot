module Response
  # Paid AI writing in default mode: "образь когось" / "образь @нік" gets a
  # roast for ROAST_FEE, "анекдот [про …]" an anecdote for ANECDOTE_FEE. The
  # fee is taken only when the model delivers: a failed or empty answer costs
  # nothing. Like "пошли @нік", a roast needs a balance that covers it; an
  # anecdote may take a balance below zero.
  class AiOrder
    include Responder

    ROAST_FEE = 150
    ANECDOTE_FEE = 50
    ROAST_RANDOM = "образь когось".freeze
    ROAST_PREFIX = "образь @".freeze
    ANECDOTE = "анекдот".freeze
    ANECDOTE_PREFIX = "анекдот про ".freeze
    # For a bare "анекдот".
    TOPICS = [ "маткор", "гатіння", "нерівні розміри", "джент", "репетиції на точці", "барабанщика, що не тримає темп" ].freeze
    UNAVAILABLE = "ШІ зараз не відповідає, жмихкоїни не списав. Спробуй пізніше.".freeze

    # command: the text after the bot's mention, lowercased.
    # random: anything with #rand, so specs can fix the picks.
    def initialize(user:, command:, chat:, random: Random)
      @user = user
      @command = command
      @chat = chat
      @random = random
    end

    def call
      if @command == ROAST_RANDOM
        roast_random
      elsif @command.start_with?(ROAST_PREFIX)
        roast_named(@command.delete_prefix(ROAST_PREFIX))
      elsif @command == ANECDOTE
        anecdote(TOPICS.sample(random: @random))
      elsif @command.start_with?(ANECDOTE_PREFIX)
        anecdote(@command.delete_prefix(ANECDOTE_PREFIX).strip.truncate(100))
      end
    end

    private

    def roast_random
      return too_poor unless Zhmykhcoins.affordable?(@user, @chat, ROAST_FEE)

      target = @chat.users.where.not(id: @user.id).to_a.sample(random: @random)
      return reply("Нема кого ображати.") unless target

      roast(target)
    end

    # As before the AI: a username nobody here has still costs the fee.
    def roast_named(username)
      return too_poor unless Zhmykhcoins.affordable?(@user, @chat, ROAST_FEE)

      # The command arrives lowercased; usernames are stored as written.
      target = @chat.users.find_by("LOWER(users.username) = ?", username)
      return roast(target) if target

      return too_poor unless spend(ROAST_FEE)

      reply("Такої людини тут нема, але #{Zhmykhcoins.count(ROAST_FEE)} я все одно забрав. Шоб не вмикала чєпуха.")
    end

    def roast(target)
      text = write(
        "Напиши жорстку, але дружню й смішну образу для #{target.name}. Можеш чіпляти те, що ця людина писала вище. " \
          "Одне-два речення, до 40 слів, на \"ти\". Не починай зі звертання: імʼя додадуть перед твоїм текстом. " \
          "Обовʼязково напиши текст, не #{::Ai::SKIP}."
      )
      return reply(UNAVAILABLE) unless text

      # Checked again: someone may have taken from the balance while the AI wrote.
      return too_poor unless spend(ROAST_FEE)

      reply("#{@user.first_name} за #{Zhmykhcoins.count(ROAST_FEE)} замовив: \n\n#{mention(target)} #{text}")
    end

    def anecdote(topic)
      text = write(
        "Розкажи один короткий анекдот (до 80 слів) про #{topic}. Він для нашого чату музикантів: можна згадувати " \
          "учасників і те, що вони писали вище. Лише сам анекдот, без вступу й пояснень. " \
          "Обовʼязково напиши текст, не #{::Ai::SKIP}."
      )
      return reply(UNAVAILABLE) unless text

      @user.points.create!(chat: @chat, amount: -ANECDOTE_FEE, reason: @command)
      reply("#{@user.first_name} замовив анекдот за #{Zhmykhcoins.count(ANECDOTE_FEE)}:\n\n#{text}")
    end

    # nil when OpenAI fails or the model writes nothing usable.
    def write(task)
      text = ::Ai.compose(@chat, task).to_s.strip
      text unless text.empty? || ::Ai.skip?(text)
    rescue OpenAI::Errors::Error => e
      Rails.logger.warn("[Response::AiOrder] Writing failed: #{e.class}: #{e.message}")
      nil
    end

    def spend(fee)
      Zhmykhcoins.spend(@user, @chat, fee, reason: @command)
    end

    def too_poor
      reply(Zhmykhcoins.not_enough(@user, @chat, ROAST_FEE))
    end

    def mention(user)
      user.username ? "@#{user.username}" : user.name
    end
  end
end
