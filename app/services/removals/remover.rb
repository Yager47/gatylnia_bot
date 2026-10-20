module Removals
  # Removes the author's own latest record in a chat and returns the reply.
  # Shared by the strict phrases ("видали каву", "видали гатіння") and the
  # requests the AI reads (Response::Removal). Only ever the author's own,
  # one at a time: a misread request can't touch anyone else's records.
  class Remover
    def initialize(user:, chat:)
      @user = user
      @chat = chat
    end

    # Text or video note alike. Push-ups can't be undone, on purpose.
    def coffee
      last_coffee = @chat.activities.coffee.where(user: @user).order(:occurred_at, :id).last
      return "Ти ще тут не пив каву" unless last_coffee

      last_coffee.destroy!
      "Видалив твою останню каву. Сьогодні: #{coffee_today}"
    end

    def gato
      last_entry = @user.entries.where(chat: @chat).order(:created_at, :id).last
      return "Ти ще тут не гатив, придурок" unless last_entry

      last_entry.destroy!
      "Твоє останнє гатіння видалено. \nТіряйся"
    end

    # The author's review of the shared release, with all its messages, so
    # it no longer counts anywhere. The bot's reactions on those messages go
    # too; a reply under the release later starts a new review.
    def review(share)
      review = Review.find_by(chat: @chat, release_id: share.release_id, user: @user)
      name = Camerton::Formatting.release(share.release)
      return "Ти ще не оцінював #{name}" unless review

      Camerton::ReviewReaction.new(review).clear
      review.destroy!
      CheckAchievementsJob.perform_later(@chat) if review.score
      "Видалив твою оцінку: #{name}"
    end

    private

    def coffee_today
      @chat.activities.coffee.where(user: @user, occurred_at: Time.current.all_day).sum(:amount)
    end
  end
end
