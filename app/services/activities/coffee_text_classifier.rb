module Activities
  # Decides whether a chat message says its author drank coffee. A coffee
  # message always counts as one cup, whatever number it mentions.
  class CoffeeTextClassifier
    Result = Data.define(:coffee, :ordinal)

    # Cheap filter run on every message before paying for a model call.
    # Over-matching is fine (the model decides); "цікаво" is too common to send.
    CANDIDATE = /(?<!ці)кав|кофе|кофі|еспресо|espresso|лате|latte|капучин|cappuccino|американо|americano|coffee/

    MODEL = "gpt-5-mini".freeze

    PROMPT = <<~TEXT.freeze
      You read one message from a Ukrainian friends' group chat (surzhyk, slang, swearing are normal).
      Decide whether the author says they themselves are drinking coffee now or just drank it today.
      If the message is about someone else drinking coffee (a name or "він/вона/ти"), it is false.
      - coffee: true for "п'ю каву", "випив каву", "перша кава", "друга кава", "кавуся", "заварив еспресо і п'ю".
        false for wishes or plans ("хочу кави", "піду за кавою"), questions ("хто на каву?"), other people's coffee,
        coffee in general ("кава це ахуєнно", "кава закінчилась"), and words that only look similar.
        Also false for corrections, counts or questions about coffee totals, often addressed to the bot
        ("-2 кави за сьогодні", "мінус одна кава", "скільки в мене кав?", "кава за тиждень").
      - ordinal: the cup number they name ("перша" = 1, "друга" = 2, "третя" = 3...), otherwise null.
    TEXT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[coffee ordinal],
      properties: {
        coffee: { type: "boolean" },
        ordinal: { type: %w[integer null] }
      }
    }.freeze

    def self.candidate?(text)
      CANDIDATE.match?(text.to_s.downcase)
    end

    def initialize(client: OpenAiClient.build)
      @client = client
    end

    def call(text)
      response = @client.chat.completions.create(
        model: MODEL,
        reasoning_effort: :low,
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: text } ],
        response_format: { type: "json_schema", json_schema: { name: "coffee_message", strict: true, schema: SCHEMA } }
      )
      verdict = JSON.parse(response.choices[0].message.content)

      Result.new(coffee: verdict["coffee"], ordinal: verdict["ordinal"])
    end
  end
end
