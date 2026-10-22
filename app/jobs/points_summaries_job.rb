# Mondays (config/recurring.yml): one weekly жмихкоїни summary job per chat
# whose mode has them, so a failure in one chat doesn't hold up the others.
class PointsSummariesJob < ApplicationJob
  queue_as :default

  def perform
    Chat.where(mode: [ :default, :accountant ]).find_each do |chat|
      SendPointsSummaryJob.perform_later(chat)
    end
  end
end
