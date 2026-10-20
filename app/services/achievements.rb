# Camerton achievements ("ачівки"): every rule a member can earn, in the
# order they're listed. See Achievements::Checker for how they're awarded.
module Achievements
  RULES = [
    Rules::SongMarathon.new(code: "song_half_marathon", title: "Пісенний Напівмарафонець", goal: 21),
    Rules::SongMarathon.new(code: "song_marathon", title: "Пісенний Марафонець", goal: 42),
    Rules::GenreTourist.new(code: "genre_tourist", title: "Жанровий турист", goal: 10),
    Rules::Chatterbox.new(code: "chatterbox", title: "Базікало", goal: 20),
    Rules::FirstListener.new(code: "first_listener", title: "Перший слухач", goal: 5),
    Rules::Lightning.new(code: "lightning", title: "Блискавка", goal: 5),
    Rules::Rescuer.new(code: "rescuer", title: "Рятувальник", goal: 3),
    Rules::Archaeologist.new(code: "archaeologist", title: "Археолог", goal: 5),
    Rules::BubbleExit.new(code: "bubble_exit", title: "Вихід з бульбашки", goal: 3),
    Rules::LongCritic.new(code: "long_critic", title: "Розгорнутий критик", goal: 5),
    Rules::Necromancer.new(code: "necromancer", title: "Некромант", goal: 5),
    Rules::Turncoat.new(code: "turncoat", title: "Перевзувач")
  ].freeze
end
