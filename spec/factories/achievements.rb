FactoryBot.define do
  factory :achievement do
    chat
    user
    code { "song_marathon" }
    period { "2026-10" }
    awarded_at { Time.current }
  end
end
