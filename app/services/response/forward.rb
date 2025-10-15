module Response
  class Forward < Response::Base
    def initialize(forward_from:)
      @forward_from = forward_from
    end
    def process
      return if @forward_from.blank?

      success answer("forward")
    end

    private

    def data
      {
        "forward" => answers("forward")
      }
    end
  end
end