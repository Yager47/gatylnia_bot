module Camerton
  # Reads everything one member said about a release: whether it's a review,
  # the score they wrote (never one guessed from their words) and a summary.
  class FeedbackAnalyzer
    Result = Data.define(:review, :score, :summary)

    MODEL = "gpt-5-mini".freeze

    PROMPT = <<~TEXT.freeze
      You read what one member of a Ukrainian friends' music chat wrote about a song or album someone shared.
      You get the release and their replies in order, possibly across several listens. Surzhyk, slang and swearing are normal.
      Replies with source "voice" or "video_note" are speech transcripts and may contain recognition mistakes.
      - review: true if they rate it or say anything about how the music sounds or how they like it.
        false if the replies are only questions, jokes, links, logistics or about something else
        ("де ти це знайшов?", "скинь ще", "о, це ж з того фільму").
      - score: only a rating they wrote themselves, as a whole number from 1 to 10:
        a bare number as the reply ("8"), "7/10", "8 з 10", "на дев'ятку", "4 з 5" (convert other scales to 10 and round).
        null when they wrote no rating, however clearly they love or hate it: never guess a score from their words.
        null when review is false. If they rated it more than once, the latest rating counts.
      - summary: their opinion in at most 12 Ukrainian words, third person, no name ("каже, що приспів топ, але інтро затягнуте").
        Only what they actually said: never add opinions or words of your own.
        Empty when review is false, and when they only gave a rating with no words about the music ("8", "7/10").
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

      return Result.new(review: false, score: nil, summary: nil) unless verdict["review"]

      Result.new(review: true, score: verdict["score"]&.clamp(1, 10), summary: verdict["summary"].strip.presence)
    end

    private

    def input(release, messages)
      JSON.generate(
        release: { kind: release.kind, artist: release.artist, title: release.title },
        replies: messages.map { |message| { date: message.sent_at.to_date.iso8601, source: message.source, text: message.text } }
      )
    end
  end
end
