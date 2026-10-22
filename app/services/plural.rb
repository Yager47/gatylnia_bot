# Ukrainian plural forms: one for 1, 21, 101; few for 2-4, 22-24; many for
# 0, 5-20, 25-30 (11-14 are always many). Negative numbers take the form of
# their absolute value.
module Plural
  module_function

  # word(3, "кава", "кави", "кав") => "кави"
  def word(number, one, few, many)
    number = number.abs
    if (11..14).cover?(number % 100) then many
    elsif number % 10 == 1 then one
    elsif (2..4).cover?(number % 10) then few
    else many
    end
  end

  # count(3, "кава", "кави", "кав") => "3 кави"
  def count(number, one, few, many)
    "#{number} #{word(number, one, few, many)}"
  end
end
