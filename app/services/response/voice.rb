module Response
  class Voice < Response::Base
    def initialize(voice:)
      @voice = voice
    end

    def call
      return if @voice.blank?

      reply(answer("voice"))
    end

    private

    def data
      {
        "voice" => answers("voice")
      }
    end
  end
end
