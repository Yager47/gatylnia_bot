module Camerton
  # The share a reply is about. Usually found by the number of the message
  # replied to: the link itself or the bot's announcement under it.
  #
  # Failing that, by the link in the replied-to message, which Telegram
  # sends along with the reply. That covers links the bot never saw under
  # its own numbering: shared before Camerton and imported from an export
  # (in a basic group, the export numbers messages per account). Only
  # messages from people: a bot echoing a link isn't the share.
  module RepliedShare
    # reply_to_message: the Telegram message replied to (nil if none).
    # replied_at: when the reply was sent; a later share isn't the one meant.
    def self.find(chat:, reply_to_message:, replied_at: Time.current)
      return unless reply_to_message

      chat.release_shares.replied_to(reply_to_message[:message_id]).first ||
        by_link(chat, reply_to_message, replied_at)
    end

    def self.by_link(chat, replied, replied_at)
      return if replied.dig(:from, :is_bot)

      link = Links.first_in(replied)
      release = link && Release.find_for(link)
      return unless release

      chat.release_shares.where(release: release, shared_at: ..replied_at).order(shared_at: :desc, id: :desc).first
    end
    private_class_method :by_link
  end
end
