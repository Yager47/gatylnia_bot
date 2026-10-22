module Response
  # Replies to a message that contains a known word or phrase: the first
  # matching rule in lib/rules/includes.yml wins.
  class Includes
    include Responder

    # first_name: as the chat calls the author (MemberNames).
    def initialize(first_name:, text:)
      @first_name = first_name
      @text = text
    end

    # The rules in file order, patterns compiled once per process.
    def self.rules
      source = AnswerFiles.yaml("rules", "includes")
      AnswerFiles.fetch([ :rules, "includes" ]) do
        source.map do |rule|
          rule["pattern"] ? rule.merge("pattern" => Regexp.new(rule["pattern"])).freeze : rule
        end.freeze
      end
    end

    def call
      rule = self.class.rules.find { |candidate| matches?(candidate) }
      reply_with_rule(rule, first_name: @first_name) if rule
    end

    private

    def matches?(rule)
      if rule["pattern"]
        rule["pattern"].match?(@text)
      elsif rule["phrases"]
        phrases(rule["phrases"]).any? { |phrase| @text.include?(phrase) }
      else
        Array(rule["contains"]).any? { |word| @text.include?(word) }
      end
    end
  end
end
