# Loads Faraday, whose errors are retried below (ChatMessenger sends through it).
require "telegram/bot"

# Re-checks a chat's achievements after something they count changed (a
# score, a removed review, a merge of two releases), and every morning
# (CheckAllAchievementsJob).
class CheckAchievementsJob < ApplicationJob
  queue_as :default

  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  # Safe to run twice: each announces only what changed since the last
  # run, under the chat's row lock.
  def perform(chat)
    Achievements::Checker.new(chat).call
    Achievements::Streaks.new(chat).call
  end
end
