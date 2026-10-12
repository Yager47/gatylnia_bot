module ChatMembers
  # Finds or creates the User for a Telegram `from` hash and makes sure they
  # belong to the chat. Safe when two jobs see the same new user at once: the
  # unique indexes turn the losing INSERT into a lookup (create_or_find_by!).
  class Resolver
    def initialize(chat:, from:)
      @chat = chat
      @from = from
    end

    def call
      user = find_or_create_user
      ChatUser.find_by(chat: @chat, user: user) || ChatUser.create_or_find_by!(chat: @chat, user: user)
      user
    end

    private

    # find_by first: the common case is a known user, and create_or_find_by!
    # alone would attempt (and roll back) an INSERT on every message.
    def find_or_create_user
      User.find_by(telegram_id: @from[:id]) ||
        User.create_or_find_by!(telegram_id: @from[:id]) do |user|
          user.username = @from[:username]
          user.first_name = @from[:first_name]
          user.last_name = @from[:last_name]
        end
    end
  end
end
