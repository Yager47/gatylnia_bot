module Response
  class Forward
    include Responder

    def initialize(forward_from:)
      @forward_from = forward_from
    end

    def call
      return if @forward_from.blank?

      reply(pick(answers("forward")))
    end
  end
end
