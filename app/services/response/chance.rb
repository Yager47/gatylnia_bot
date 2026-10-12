module Response
  class Chance < Response::Base
    def call
      reply(answer("chance"))
    end

    private

    def rhythm
      TimeSignature.call
    end

    def data
      {
        "chance" => answers("chance", rhythm: rhythm).sample(10)
      }
    end
  end
end
