class TimeSignature
  def self.call
    "#{upper}/#{lower}"
  end

  private

  def self.upper
    [3, 5, 6, 7, 9, 10, 11, 13, 14, 15].sample
  end

  def self.lower
    [4, 8, 16].sample
  end
end
