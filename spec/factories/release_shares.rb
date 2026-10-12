FactoryBot.define do
  factory :release_share do
    chat
    release
    user
    sequence(:telegram_message_id) { |n| 10_000 + n }
    shared_at { Time.current }
  end
end
