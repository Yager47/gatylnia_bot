require "erb"

module Camerton
  # How Camerton writes releases, scores and counts in its messages.
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
    # links; in a basic group it's just the escaped name.
    def release_link(share, chat)
      name = ERB::Util.html_escape(release(share.release))
      internal_id = chat.telegram_id.to_s.delete_prefix("-100")
      return name if internal_id == chat.telegram_id.to_s

      %(<a href="https://t.me/c/#{internal_id}/#{share.telegram_message_id}">#{name}</a>)
    end

    def kind(release)
      KINDS.fetch(release.kind)
    end

    # 7.5, 8 (not 8.0), 7.3 for 7.33.
    def score(value)
      format("%g", value.to_f.round(1))
    end

    # Ukrainian plural: count(1, "оцінка", "оцінки", "оцінок") => "1 оцінка",
    # 3 => "3 оцінки", 5 and 11-14 => "... оцінок".
    def count(number, one, few, many)
      word =
        if (11..14).cover?(number % 100) then many
        elsif number % 10 == 1 then one
        elsif (2..4).cover?(number % 10) then few
        else many
        end

      "#{number} #{word}"
    end
  end
end
