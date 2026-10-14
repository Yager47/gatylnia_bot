FactoryBot.define do
  factory :audio_track do
    chat
    user
    sequence(:telegram_message_id) { |n| 20_000 + n }
    file_name { "demo.mp3" }
    sent_at { Time.current }
  end
end
