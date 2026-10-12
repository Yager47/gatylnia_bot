module Camerton
  module Platforms
    module YoutubeMusic
      NAME = "youtube_music".freeze
      HOST = "music.youtube.com".freeze
      VIDEO_ID = /\A[A-Za-z0-9_-]{11}\z/
      # Albums are auto-generated playlists with this prefix; other playlists
      # are user-made mixes, not releases.
      ALBUM_LIST_ID = /\AOLAK5uy_[A-Za-z0-9_-]+\z/
      # A playlist's oEmbed thumbnail is its first track's.
      THUMBNAIL_VIDEO_ID = %r{/vi/([A-Za-z0-9_-]{11})/}

      # Returns a Link for a song (/watch?v=) or album (/playlist?list=OLAK5uy_)
      # URL, or nil for anything else.
      def self.parse(url)
        uri = URI.parse(url)
        return unless uri.host&.downcase == HOST

        params = URI.decode_www_form(uri.query.to_s).to_h
        case uri.path
        when "/watch" then song(params["v"])
        when "/playlist" then album(params["list"])
        end
      rescue URI::InvalidURIError, ArgumentError
        nil
      end

      # Raw names for a release, or nil when YouTube has none. oEmbed gives an
      # album no artist, so it comes from the first track's channel
      # ("Eminem - Topic").
      def self.source_metadata(release, oembed: YoutubeOembed.new)
        data = oembed.fetch(release.url)
        return unless data

        author = release.album? ? first_track_author(data, oembed) : data["author_name"]
        SourceMetadata.new(title: data["title"], author: author)
      end

      def self.song(video_id)
        return unless VIDEO_ID.match?(video_id.to_s)

        Link.new(platform: NAME, kind: :song, external_id: video_id, url: "https://#{HOST}/watch?v=#{video_id}")
      end
      private_class_method :song

      def self.album(list_id)
        return unless ALBUM_LIST_ID.match?(list_id.to_s)

        Link.new(platform: NAME, kind: :album, external_id: list_id, url: "https://#{HOST}/playlist?list=#{list_id}")
      end
      private_class_method :album

      def self.first_track_author(playlist_data, oembed)
        video_id = playlist_data["thumbnail_url"].to_s[THUMBNAIL_VIDEO_ID, 1]
        return unless video_id

        oembed.fetch("https://#{HOST}/watch?v=#{video_id}")&.dig("author_name")
      end
      private_class_method :first_track_author
    end
  end
end
