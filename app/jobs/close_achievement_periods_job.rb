# Mondays and the 1st of the month (config/recurring.yml): one job per
# Camerton chat, so a failure in one chat doesn't hold up the others.
class CloseAchievementPeriodsJob < ApplicationJob
  queue_as :default

  # kind: "week" or "month" (recurring.yml passes strings).
  def perform(kind)
    Chat.where(camerton_enabled: true).find_each do |chat|
      CloseChatAchievementsJob.perform_later(chat, kind)
    end
  end
end
