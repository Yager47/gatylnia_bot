FactoryBot.define do
  factory :telegram_update do
    sequence(:update_id) { |n| 900_000_000 + n }
    update_type { "message" }
    payload do
      {
        "update_id" => update_id,
        "message" => {
          "message_id" => 1,
          "date" => Time.current.to_i,
          "chat" => { "id" => -1_001_234_567_890, "type" => "supergroup", "title" => "Гатильня" },
          "from" => { "id" => 555, "is_bot" => false, "first_name" => "Петро" },
          "text" => "Ало"
        }
      }
    end
  end
end
