require "erb"

module Camerton
  # How Camerton writes releases and scores in its messages.
  module Formatting
    ICONS = { "song" => "🎵", "album" => "💿" }.freeze
    KINDS = { "song" => "пісня", "album" => "альбом" }.freeze

    module_function

    # "🎵 Queen — Bohemian Rhapsody", just the title when the artist is
    # unknown, or the link while the release has no name.
    def release(release)
      name = release.resolved? ? [ release.artist, release.title ].compact.join(" — ") : release.url
      "#{ICONS.fetch(release.kind)} #{name}"
    end

    # Telegram HTML: the release as a link to the shared message, so a tap
    # jumps to it. Only supergroups (ids starting with -100) have t.me/c
    # links, and only for messages posted after the chat became one: earlier
    # ones keep the old basic group's ids. Otherwise it links to the release
    # on its platform (YouTube Music).
    def release_link(share, chat)
      name = ERB::Util.html_escape(release(share.release))
      url = message_url(share, chat) || share.release.url

      %(<a href="#{ERB::Util.html_escape(url)}">#{name}</a>)
    end

    # The shared message's t.me/c link, or nil when it has none.
    def message_url(share, chat)
      internal_id = chat.telegram_id.to_s.delete_prefix("-100")
      return if internal_id == chat.telegram_id.to_s
      return if chat.supergroup_since && share.shared_at < chat.supergroup_since

      "https://t.me/c/#{internal_id}/#{share.telegram_message_id}"
    end

    # Telegram HTML: @username notifies by itself; without one, a mention
    # link does.
    def mention(user)
      return "@#{user.username}" if user.username.present?

      %(<a href="tg://user?id=#{user.telegram_id}">#{ERB::Util.html_escape(user.name)}</a>)
    end

    def kind(release)
      KINDS.fetch(release.kind)
    end

    # 7.5, 8 (not 8.0), 7.3 for 7.33.
    def score(value)
      format("%g", value.to_f.round(1))
    end
  end
end
