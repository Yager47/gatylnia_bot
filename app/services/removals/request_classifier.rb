module Removals
  # Reads a command sent to the bot and decides which of the author's own
  # latest records they ask to remove: "coffee", "gato", "review" or nil.
  # The model only names a kind; which record goes (the author's latest, in
  # this chat) is up to Remover, so a misread can't reach anyone else's.
  class RequestClassifier
    KINDS = %w[coffee gato review].freeze
    NONE = "none".freeze

    # Cheap filters run before paying for a model call: a removal verb and a
    # word for one of the kinds asked about. Over-matching is fine.
    VERB = /видал|прибер|прибра|скасу|відмін|забер|зітр|стер|удал|delete|remove|undo/
    SUBJECTS = {
      "coffee" => /кав|коф|еспресо|espresso|coffee/,
      "gato" => /гат|сра|сру|кака|дрис|дрищ|дріщ/,
      "review" => /оцін|ревю|рев['’ʼ]ю|рецензі|відгук|review/
    }.freeze

    MODEL = "gpt-5-mini".freeze

    DESCRIPTIONS = {
      "coffee" => %(coffee: a cup of coffee they logged ("видали останню каву", "прибери каву", "скасуй каву, я не пив")),
      "gato" => %(gato: a toilet visit they logged, called гатіння ("видали гатіння", "прибери останнє гатіння", "я не гатив, забери")),
      "review" => %(review: their score of the music release the command replies to ("видали мою оцінку", "прибери моє ревю"))
    }.freeze

    # kinds: the kinds this chat has, so a candidate needs a word for one.
    def self.candidate?(command, kinds)
      text = command.to_s.downcase
      VERB.match?(text) && kinds.any? { |kind| SUBJECTS.fetch(kind).match?(text) }
    end

    def initialize(client: OpenAiClient.build)
      @client = client
    end

    def call(command, kinds:)
      response = @client.chat.completions.create(
        model: MODEL,
        reasoning_effort: :low,
        messages: [ { role: "system", content: prompt(kinds) }, { role: "user", content: command } ],
        response_format: { type: "json_schema", json_schema: { name: "removal_request", strict: true, schema: schema(kinds) } }
      )
      kind = JSON.parse(response.choices[0].message.content)["kind"]

      kind if kinds.include?(kind)
    end

    private

    def prompt(kinds)
      <<~TEXT
        You read one command a member of a Ukrainian friends' group chat sent to the chat's bot (surzhyk, slang, swearing are normal).
        Decide whether they ask the bot to remove their own latest record of one of these kinds:
        #{kinds.map { |kind| "- #{DESCRIPTIONS.fetch(kind)}" }.join("\n")}
        Answer "#{NONE}" unless it is a clear request to remove their own single latest record: jokes, questions,
        negations ("не видаляй каву"), someone else's record ("видали каву Олі"), several or a specific older one
        ("видали всі кави", "видали вчорашнє гатіння"), and asking to add or count something are all "#{NONE}".
      TEXT
    end

    def schema(kinds)
      {
        type: "object",
        additionalProperties: false,
        required: %w[kind],
        properties: { kind: { type: "string", enum: kinds + [ NONE ] } }
      }
    end
  end
end
