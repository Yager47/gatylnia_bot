module Response
  class Voice
    include Responder

    def initialize(voice:)
      @voice = voice
    end

    def call
      return if @voice.blank?

      reply(pick(answers("voice")))
    end
  end
end
