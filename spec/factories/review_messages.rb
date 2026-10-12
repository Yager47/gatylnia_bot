FactoryBot.define do
  factory :review_message do
    review
    release_share { association :release_share, chat: review.chat, release: review.release }
    sequence(:telegram_message_id) { |n| 50_000 + n }
    source { :text }
    text { "норм трек" }
    sent_at { Time.current }
  end
end
