module Response
  class Chance
    include Responder

    def call
      reply(pick(render_answers("chance", rhythm: TimeSignature.call)))
    end
  end
end
