module Achievements
  # A calendar week (Monday to Sunday) or month in Kyiv time
  # (config.time_zone), whatever zone the server runs in.
  #   Period.current(:month).key # => "2026-10"
  #   Period.current(:week).key  # => "2026-W43" (ISO week-numbering year)
  class Period
    KINDS = %i[week month].freeze

    attr_reader :kind, :range

    def self.current(kind, now: Time.current)
      raise ArgumentError, "unknown period kind: #{kind.inspect}" unless KINDS.include?(kind)

      now = now.in_time_zone
      range = kind == :week ? now.all_week(:monday) : now.all_month
      new(kind, range)
    end

    def initialize(kind, range)
      @kind = kind
      @range = range
    end

    def key
      kind == :week ? range.begin.strftime("%G-W%V") : range.begin.strftime("%Y-%m")
    end
  end
end
