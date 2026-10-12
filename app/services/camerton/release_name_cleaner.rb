module Camerton
  # Turns a platform's raw title and channel name into the artist and title a
  # music service would show ("Queen Official" + "Queen – Bohemian Rhapsody
  # (Official Video Remastered)" => "Queen", "Bohemian Rhapsody").
  class ReleaseNameCleaner
    Result = Data.define(:artist, :title)

    MODEL = "gpt-5-mini".freeze

    PROMPT = <<~TEXT.freeze
      You get raw YouTube Music metadata for one release: its kind (song or album), title and channel name.
      Return the artist and title as a music streaming service would show them.
      - artist: the performing artist(s). Drop channel suffixes such as " - Topic", "VEVO", "Official", "Records".
        If the title starts with "Artist - " or "Artist – ", that is the artist. Join several main artists with ", ".
      - title: the song or album name only. Drop video labels such as "(Official Video)", "(Official Audio)",
        "(Lyric Video)", "(Visualizer)", "[HD]", and album prefixes such as "Album - ", "EP - ", "Single - ".
        Keep version info that is part of the name: "(Remastered 2011)", "(Live)", "(Acoustic)", "(feat. X)".
      - Keep the original language and spelling; don't translate or transliterate.
      - If the channel is missing or says nothing about the artist, infer it from the title, or return "" if you can't.
    TEXT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[artist title],
      properties: {
        artist: { type: "string" },
        title: { type: "string" }
      }
    }.freeze

    def initialize(client: OpenAiClient.build)
      @client = client
    end

    def call(kind:, source:)
      response = @client.chat.completions.create(
        model: MODEL,
        reasoning_effort: :low,
        messages: [
          { role: "system", content: PROMPT },
          { role: "user", content: JSON.generate(kind: kind, title: source.title, channel: source.author) }
        ],
        response_format: { type: "json_schema", json_schema: { name: "release_name", strict: true, schema: SCHEMA } }
      )
      names = JSON.parse(response.choices[0].message.content)

      Result.new(artist: names["artist"].strip, title: names["title"].strip)
    end
  end
end
