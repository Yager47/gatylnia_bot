# Camerton achievements ("ачівки"): every rule a member can earn, in the
# order they're listed. See Achievements::Checker for how they're awarded.
module Achievements
  RULES = [
    Rules::SongMarathon.new(code: "song_half_marathon", title: "Пісенний Напівмарафонець", goal: 21),
    Rules::SongMarathon.new(code: "song_marathon", title: "Пісенний Марафонець", goal: 42)
  ].freeze
end
