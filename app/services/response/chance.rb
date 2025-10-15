module Response
  class Chance < Response::Base
    def process
      return unless chance(0.2)

      success answer("chance")
    end

    private

    def chance(value)
      value > rand
    end

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