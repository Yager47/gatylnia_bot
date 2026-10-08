FactoryBot.define do
  factory :message do
    chat
    user
    role { :user }
    content { "Привіт" }
    sequence(:telegram_message_id) { |n| n }
  end
end
