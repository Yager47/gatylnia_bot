module Camerton
  # Reads everything one member said about a release and decides how much
  # they liked it.
  class FeedbackAnalyzer
    Result = Data.define(:review, :score, :summary)

    MODEL = "gpt-5-mini".freeze

    PROMPT = <<~TEXT.freeze
      You read what one member of a Ukrainian friends' music chat wrote about a song or album someone shared.
      You get the release and their replies in order, possibly across several listens. Surzhyk, slang and swearing are normal.
      - review: true if they say anything about how the music sounds or how they like it.
        false if the replies are only questions, jokes, links, logistics or about something else
        ("де ти це знайшов?", "скинь ще", "о, це ж з того фільму").
      - score: how much they like it overall, a whole number from 1 to 10; null when review is false.
        1-3 bad (dislike), 4-5 mid (meh, okay), 6-8 good, 9-10 great (love it, masterpiece).
        An explicit rating ("7/10", "8 з 10", "на дев'ятку", "4 з 5") wins: convert other scales to 10 and round.
        If their opinion changed over time, the latest replies matter most.
      - summary: their opinion in at most 12 Ukrainian words, third person, no name ("каже, що приспів топ, але інтро затягнуте").
        Empty when review is false.
    TEXT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[review score summary],
      properties: {
        review: { type: "boolean" },
        score: { type: %w[integer null] },
        summary: { type: "string" }
      }
    }.freeze

    def initialize(client: OpenAiClient.build)
      @client = client
    end

    # messages: ReviewMessages, oldest first.
    def call(release:, messages:)
      response = @client.chat.completions.create(
        model: MODEL,
        reasoning_effort: :low,
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: input(release, messages) } ],
        response_format: { type: "json_schema", json_schema: { name: "music_feedback", strict: true, schema: SCHEMA } }
      )
      verdict = JSON.parse(response.choices[0].message.content)

      score = verdict["review"] ? verdict["score"]&.clamp(1, 10) : nil
      Result.new(review: verdict["review"], score: score, summary: score ? verdict["summary"].strip.presence : nil)
    end

    private

    def input(release, messages)
      JSON.generate(
        release: { kind: release.kind, artist: release.artist, title: release.title },
        replies: messages.map { |message| { date: message.sent_at.to_date.iso8601, text: message.text } }
      )
    end
  end
end
