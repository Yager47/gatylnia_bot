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
    Rules::Turncoat.new(code: "turncoat", title: "Перевзувач"),
    # Decided at the end of the week or month.
    Rules::SharerTitle.new(code: "best_sharer", title: "Найшанованіший камертон тижня", worst: false),
    Rules::SharerTitle.new(code: "worst_sharer", title: "Найзневаженіший камертон тижня", worst: true, secret: true),
    Rules::Eater.new(code: "song_eater", title: "Пісенний Пожирач", kinds: %w[song]),
    Rules::Eater.new(code: "album_eater", title: "Альбомний Пожирач", kinds: %w[album]),
    Rules::Eater.new(code: "eater", title: "Пожирач", kinds: %w[song album]),
    Rules::AllPositive.new(code: "all_positive", title: "Всеїдний"),
    Rules::Grumbler.new(code: "grumbler", title: "Буркотун", secret: true),
    Rules::Contrarian.new(code: "contrarian", title: "Не такий як всі", secret: true),
    Rules::ReleaseVerdict.new(code: "unanimous", title: "Одностайність", spread: 0..1, wording: "розійшлися не більше ніж на 1 бал"),
    Rules::ReleaseVerdict.new(code: "split", title: "Розкол", spread: 6.., wording: "розійшлися на 6+ балів", secret: true),
    Rules::Streak.new(code: "streak", title: "Серія")
  ].freeze
end
