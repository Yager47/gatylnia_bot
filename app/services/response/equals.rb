module Response
  # Replies to a message that is exactly a known phrase (lib/rules/equals.yml),
  # and throws insults back.
  class Equals
    include Responder

    TALK_BACK_PREFIX = "ти ".freeze

    def initialize(text:)
      @text = text
    end

    # Phrase => rule, built once per process (see AnswerFiles).
    def self.rules
      source = AnswerFiles.yaml("rules", "equals")
      AnswerFiles.fetch([ :rules, "equals" ]) do
        source.each_with_object({}) do |rule, index|
          Array(rule["match"]).each { |phrase| index[phrase] = rule }
        end.freeze
      end
    end

    def call
      # "ти <insult>" gets the insult thrown back.
      return reply(talk_back_answer) if swear_phrases.include?(insult)

      rule = self.class.rules[@text]
      return reply_with_rule(rule) if rule

      reply(pick(swear_answers)) if swear_phrases.include?(@text)
    end

    private

    def insult
      @text.delete_prefix(TALK_BACK_PREFIX) if @text.start_with?(TALK_BACK_PREFIX)
    end

    def talk_back_answer
      [ "Ти шо сука", "Ні, ти #{insult}" ].sample
    end

    def swear_answers
      result = [ "Ти шо сука", "Ні, ти #{@text}" ]
      result << "Я піду, а чи повернусь я?" if fu_phrases.include?(@text)
      result
    end
  end
end
