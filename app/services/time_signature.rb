class TimeSignature
  UPPERS = [ 3, 5, 6, 7, 9, 10, 11, 13, 14, 15 ].freeze
  LOWERS = [ 4, 8, 16 ].freeze

  def self.call
    "#{UPPERS.sample}/#{LOWERS.sample}"
  end
end
