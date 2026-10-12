FactoryBot.define do
  factory :release do
    platform { "youtube_music" }
    sequence(:external_id) { |n| format("vid%08d", n) }
    kind { :song }
    url { "https://music.youtube.com/watch?v=#{external_id}" }

    trait :resolved do
      status { :resolved }
      artist { "Queen" }
      title { "Bohemian Rhapsody" }
    end

    trait :album do
      kind { :album }
      sequence(:external_id) { |n| format("OLAK5uy_album%08d", n) }
      url { "https://music.youtube.com/playlist?list=#{external_id}" }
    end
  end
end
