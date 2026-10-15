# Renumbers a chat's messages from before it became a supergroup (see
# PreSupergroupMessageIds), off the webhook. Safe to run twice.
class NegatePreSupergroupMessageIdsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(chat)
    renumbered = PreSupergroupMessageIds.new(chat).call
    Rails.logger.info("[NegatePreSupergroupMessageIdsJob] chat #{chat.id}: #{renumbered.inspect}")
  end
end
