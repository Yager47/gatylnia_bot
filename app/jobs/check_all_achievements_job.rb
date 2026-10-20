# Daily (config/recurring.yml): re-checks every Camerton chat, so a Серія
# ends the morning after a day without a review even if nobody writes.
class CheckAllAchievementsJob < ApplicationJob
  queue_as :default

  def perform
    Chat.where(camerton_enabled: true).find_each do |chat|
      CheckAchievementsJob.perform_later(chat)
    end
  end
end
