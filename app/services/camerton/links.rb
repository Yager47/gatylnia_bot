module Camerton
  # Finds the first supported music link in a Telegram message.
  module Links
    PLATFORMS = [ Platforms::YoutubeMusic ].index_by { |platform| platform::NAME }.freeze
    URL = %r{https?://[^\s<>"]+}

    def self.first_in(message)
      candidate_urls(message).each do |url|
        PLATFORMS.each_value do |platform|
          link = platform.parse(url)
          return link if link
        end
      end

      nil
    end

    def self.platform(name)
      PLATFORMS.fetch(name)
    end

    # Plain URLs in the text or caption, then hyperlinked words (text_link
    # entities). Matching the text directly: entity offsets are in UTF-16
    # code units, not Ruby characters.
    def self.candidate_urls(message)
      text = message[:text] || message[:caption]
      entities = Array(message[:entities]) + Array(message[:caption_entities])

      text.to_s.scan(URL) + entities.filter_map { |entity| entity[:url] if entity[:type] == "text_link" }
    end
    private_class_method :candidate_urls
  end
end
