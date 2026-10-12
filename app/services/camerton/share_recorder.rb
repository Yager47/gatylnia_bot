module Camerton
  # Runs before the chat's mode handler when Camerton is on: a message with a
  # music link becomes a ReleaseShare, and replies to it become feedback.
  # Safe to run twice for the same message (unique indexes, create_or_find_by!).
  class ShareRecorder
    def initialize(message:, chat:)
      @message = message
      @chat = chat
    end

    def call
      # An edit can't turn a message into a share: replies may already exist.
      return if @message[:edit_date].present?

      link = Links.first_in(@message)
      return unless link

      share = record_share(find_or_create_release(link))
      AnnounceReleaseJob.perform_later(share) unless share.announced_at
    end

    private

    def find_or_create_release(link)
      Release.find_by(platform: link.platform, external_id: link.external_id) ||
        Release.create_or_find_by!(platform: link.platform, external_id: link.external_id) do |release|
          release.kind = link.kind
          release.url = link.url
        end
    end

    def record_share(release)
      @chat.release_shares.create_or_find_by!(telegram_message_id: @message[:message_id]) do |share|
        share.release = release
        share.user = ChatMembers::Resolver.new(chat: @chat, from: @message[:from]).call
        share.shared_at = Time.zone.at(@message[:date])
      end
    end
  end
end
