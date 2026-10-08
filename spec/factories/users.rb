FactoryBot.define do
  factory :user do
    sequence(:telegram_id) { |n| (100_000 + n).to_s }
    sequence(:username) { |n| "user#{n}" }
    first_name { "Іван" }
    last_name { "Тестовий" }
  end
end
