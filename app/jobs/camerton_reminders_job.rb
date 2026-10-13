# Daily (config/recurring.yml): one digest job per Camerton chat, so a
# failure in one chat doesn't hold up the others.
class CamertonRemindersJob < ApplicationJob
  queue_as :default

  def perform
    Chat.where(camerton_enabled: true).find_each do |chat|
      SendCamertonDigestJob.perform_later(chat)
    end
  end
end
