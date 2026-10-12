module Activities
  # Decides from frames and a transcript whether a video note shows its
  # author drinking coffee and/or doing push-ups. Tuned on 23 real notes:
  # 22 right with 6 low-detail frames (beer in a clear glass reads as coffee).
  class VideoNoteClassifier
    Result = Data.define(:coffee, :ordinal, :push_ups) do
      def kinds
        [ (:coffee if coffee), (:push_ups if push_ups) ].compact
      end
    end

    MODEL = "gpt-5-mini".freeze

    PROMPT = <<~TEXT.freeze
      You classify a Telegram video note (a short round selfie video) from a Ukrainian friends' group chat.
      You get evenly spaced frames from the video, in order, and a speech transcript (Ukrainian).
      The transcript comes from automatic speech recognition: on silent or noisy clips it can be empty or contain
      made-up text (e.g. "Дякую за перегляд!"). Trust the frames when the transcript doesn't fit them.

      Decide independently:
      - coffee: true if the person drinks or sips from a cup/mug/glass in the video, or clearly says they are drinking coffee now
        ("перша кава", "друга кава", "кава", "кофе"...). A cup with an unknown drink counts as coffee.
        Clearly NOT coffee: beer, wine, alcohol, a beer can/bottle, water from a plastic bottle, energy drink cans.
        Coffee is dark/brown or milky and usually in a mug or paper/takeaway cup. A transparent glass with a pale, golden,
        yellowish or clear drink is beer or water, not coffee, unless coffee is mentioned.
        Holding or showing a cup without drinking, with no coffee mentioned, is not enough.
      - ordinal: the cup number if they say it ("перша" = 1, "друга" = 2, "третя" = 3...), otherwise null.
      - push_ups: true if the person is doing push-ups (or similar floor press-ups) in the video.
    TEXT

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      required: %w[coffee ordinal push_ups],
      properties: {
        coffee: { type: "boolean" },
        ordinal: { type: %w[integer null] },
        push_ups: { type: "boolean" }
      }
    }.freeze

    def initialize(client: OpenAiClient.build)
      @client = client
    end

    def call(frame_paths:, transcript:)
      response = @client.chat.completions.create(
        model: MODEL,
        reasoning_effort: :low,
        messages: [ { role: "system", content: PROMPT }, { role: "user", content: content(frame_paths, transcript) } ],
        response_format: { type: "json_schema", json_schema: { name: "video_note_activity", strict: true, schema: SCHEMA } }
      )
      verdict = JSON.parse(response.choices[0].message.content)

      Result.new(coffee: verdict["coffee"], ordinal: verdict["ordinal"], push_ups: verdict["push_ups"])
    end

    private

    def content(frame_paths, transcript)
      parts = [ { type: "text", text: "Transcript: #{transcript.presence || '(empty)'}" } ]
      frame_paths.each do |path|
        parts << { type: "image_url", image_url: { url: "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(path))}", detail: "low" } }
      end
      parts
    end
  end
end
