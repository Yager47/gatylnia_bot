FactoryBot.define do
  factory :track_note do
    audio_track
    user
    sequence(:telegram_message_id) { |n| 30_000 + n }
    source { :text }
    text { "Бас тихий" }
    sent_at { Time.current }
  end
end
