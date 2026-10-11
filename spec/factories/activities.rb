FactoryBot.define do
  factory :activity do
    chat
    user
    kind { :coffee }
    source { :text }
    sequence(:telegram_message_id) { |n| n }
    occurred_at { Time.current }

    trait :push_ups do
      kind { :push_ups }
      source { :video_note }
    end
  end
end
