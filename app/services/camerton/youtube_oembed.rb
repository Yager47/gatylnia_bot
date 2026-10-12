require "net/http"

module Camerton
  # YouTube's keyless oEmbed endpoint: a title and channel name for a video or
  # playlist URL.
  class YoutubeOembed
    # Worth retrying: rate limited (429), a server error, or a network failure.
    class TransientError < StandardError; end

    ENDPOINT = "https://www.youtube.com/oembed".freeze
    TIMEOUT = 5 # seconds

    NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET ].freeze

    # Returns the parsed response, or nil when YouTube has nothing to embed:
    # deleted, private or non-embeddable (400, 401, 403, 404).
    def fetch(url)
      code, body = request(URI("#{ENDPOINT}?#{URI.encode_www_form(format: 'json', url: url)}"))

      case code
      when 200 then JSON.parse(body)
      when 429, 500.. then raise TransientError, "YouTube oEmbed answered #{code}"
      end
    end

    private

    def request(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      [ response.code.to_i, response.body ]
    rescue *NETWORK_ERRORS => e
      raise TransientError, "YouTube oEmbed unreachable: #{e.class}"
    end
  end
end
