module Response
  # "@bot видали останню каву", "@bot прибери гатіння", or "@bot видали мою
  # оцінку" in reply to a release: a removal request in the author's own
  # words, read by the AI (Removals::RequestClassifier). Coffee and gato in
  # default mode, reviews wherever Camerton is on. A request it can't do
  # (someone else's, an older one) gets told what it can do, never an AI
  # chat reply that might pretend something was removed.
  class Removal
    include Responder

    REPLY_TO_RELEASE = "Відповідай цією командою на посилання з релізом або на мою відповідь під ним.".freeze

    def initialize(user:, text:, chat:, reply_to_message: nil, classifier: nil)
      @user = user
      @chat = chat
      @reply_to_message = reply_to_message
      @classifier = classifier
      # nil unless the text starts with the mention followed by a command.
      @command = text[/\A#{Regexp.escape(BotMention.text)}\s+(.+)/m, 1]
    end

    def call
      return unless @command && Removals::RequestClassifier.candidate?(@command, kinds)

      case classifier.call(@command, kinds: kinds)
      when "coffee" then reply(remover.coffee)
      when "gato" then reply(remover.gato)
      when "review" then remove_review
      else reply(what_i_can)
      end
    rescue OpenAI::Errors::Error => e
      Rails.logger.warn("[Response::Removal] Classifying failed: #{e.class}: #{e.message}")
      reply(what_i_can)
    end

    private

    def kinds
      @kinds ||= [ *(%w[coffee gato] if @chat.default?), *("review" if @chat.camerton_enabled?) ]
    end

    def remove_review
      share = Camerton::RepliedShare.find(chat: @chat, reply_to_message: @reply_to_message)
      return reply(REPLY_TO_RELEASE) unless share

      reply(remover.review(share))
    end

    def what_i_can
      things = {
        "coffee" => "твою останню каву",
        "gato" => "твоє останнє гатіння",
        "review" => "твою оцінку релізу (відповіддю на нього)"
      }.values_at(*kinds)

      "Можу прибрати лише #{things.to_sentence(two_words_connector: ' чи ', last_word_connector: ' чи ')}."
    end

    def remover
      Removals::Remover.new(user: @user, chat: @chat)
    end

    def classifier
      @classifier ||= Removals::RequestClassifier.new
    end
  end
end
