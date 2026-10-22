# The chat's points go by "жмихкоїни" in replies. They're stored as plain
# integers in Point#amount; this only names them.
module Zhmykhcoins
  module_function

  # 1 => "1 жмихкоїн", 3 => "3 жмихкоїни", 5 or 11 => "5 жмихкоїнів".
  # signed: true writes gains as "+50".
  def count(amount, signed: false)
    number = signed ? format("%+d", amount) : amount.to_s
    "#{number} #{Plural.word(amount, 'жмихкоїн', 'жмихкоїни', 'жмихкоїнів')}"
  end
end
