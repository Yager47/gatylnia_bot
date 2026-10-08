FactoryBot.define do
  factory :chat do
    sequence(:telegram_id) { |n| (-1_000_000_000_000 - n).to_s }
    telegram_type { "supergroup" }
    sequence(:title) { |n| "Chat #{n}" }
    mode { :default }
  end
end
