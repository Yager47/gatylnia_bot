require "net/http"

module Camerton
  # The Discogs database API: search and master releases. Works without a
  # token (25 requests a minute); DISCOGS_TOKEN raises that to 60.
  class Discogs
    class Error < StandardError; end
    # Worth trying again later: rate limited (429), a server error, or a
    # network failure.
    class TransientError < Error; end

    HOST = "api.discogs.com".freeze
    # Discogs rejects requests without a User-Agent naming the app.
    USER_AGENT = "GatylniaBot/1.0 +https://github.com/Yager47/gatylnia_bot".freeze
    TIMEOUT = 3 # seconds

    NETWORK_ERRORS = [ Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET ].freeze

    def initialize(token: ENV["DISCOGS_TOKEN"])
      @token = token.presence
    end

    def requests_per_minute
      @token ? 60 : 25
    end

    # Master releases matching the params (artist:, track: or release_title:),
    # as Discogs ranks them.
    def search_masters(**params)
      get("/database/search", type: "master", per_page: 100, **params)&.fetch("results", []) || []
    end

    # Nil when the master doesn't exist (any more).
    def master(id)
      get("/masters/#{Integer(id)}")
    end

    private

    def get(path, params = {})
      uri = URI::HTTPS.build(host: HOST, path: path, query: params.presence && URI.encode_www_form(params))
      code, body = request(uri)

      case code
      when 200 then JSON.parse(body)
      when 404 then nil
      when 429, 500.. then raise TransientError, "Discogs answered #{code}"
      else raise Error, "Discogs answered #{code}"
      end
    end

    def request(uri)
      headers = { "User-Agent" => USER_AGENT }
      headers["Authorization"] = "Discogs token=#{@token}" if @token

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri, headers))
      end
      [ response.code.to_i, response.body ]
    rescue *NETWORK_ERRORS => e
      raise TransientError, "Discogs unreachable: #{e.class}"
    end
  end
end
