module Response
  class Voice < Response::Base
    def initialize(voice:)
      @voice = voice
    end

    def process
      return if @voice.blank?

      success answer("voice")
    end

    private

    def data
      {
        "voice" => answers("voice")
      }
    end
  end
end