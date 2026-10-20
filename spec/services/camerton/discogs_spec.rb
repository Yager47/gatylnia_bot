require "rails_helper"

RSpec.describe Camerton::Discogs do
  subject(:discogs) { described_class.new(token: nil) }

  def discogs_answers(code, body = "")
    allow(discogs).to receive(:request).and_return([ code, body ])
  end

  describe "#search_masters" do
    it "searches masters only, 100 per page, and returns the results" do
      discogs_answers(200, '{"results":[{"id":1,"title":"Queen - A Night At The Opera"}]}')

      results = discogs.search_masters(artist: "Queen", track: "Bohemian Rhapsody")

      expect(results).to eq([ { "id" => 1, "title" => "Queen - A Night At The Opera" } ])
      expect(discogs).to have_received(:request).with(
        URI("https://api.discogs.com/database/search?type=master&per_page=100&artist=Queen&track=Bohemian+Rhapsody")
      )
    end

    it "returns no results when the search is gone" do
      discogs_answers(404)

      expect(discogs.search_masters(artist: "Queen")).to eq([])
    end
  end

  describe "#master" do
    it "fetches the master by id" do
      discogs_answers(200, '{"id":1210,"year":1975}')

      expect(discogs.master(1210)).to eq("id" => 1210, "year" => 1975)
      expect(discogs).to have_received(:request).with(URI("https://api.discogs.com/masters/1210"))
    end

    it "returns nil for a missing master" do
      discogs_answers(404)

      expect(discogs.master(1210)).to be_nil
    end
  end

  it "raises a transient error on rate limiting and server errors" do
    [ 429, 500, 503 ].each do |code|
      discogs_answers(code)

      expect { discogs.master(1) }.to raise_error(described_class::TransientError, /#{code}/)
    end
  end

  it "raises a plain error on other unexpected answers" do
    discogs_answers(401)

    expect { discogs.master(1) }.to raise_error(described_class::Error, /401/) { |error| expect(error).not_to be_a(described_class::TransientError) }
  end

  it "knows the rate limit, higher with a token" do
    expect([ discogs.requests_per_minute, described_class.new(token: "secret").requests_per_minute ]).to eq([ 25, 60 ])
  end

  describe "the request" do
    let(:http) { instance_double(Net::HTTP, request: instance_double(Net::HTTPOK, code: "200", body: "{}")) }

    before do
      allow(discogs).to receive(:request).and_call_original
      allow(Net::HTTP).to receive(:start).and_yield(http)
    end

    def sent_headers
      request = nil
      expect(http).to have_received(:request) { |sent| request = sent }
      request
    end

    it "names the app and sends no token without one" do
      discogs.master(1)

      expect(sent_headers["User-Agent"]).to eq(described_class::USER_AGENT)
      expect(sent_headers["Authorization"]).to be_nil
    end

    it "sends the token when there is one" do
      described_class.new(token: "secret").tap { |client| allow(client).to receive(:request).and_call_original }.master(1)

      expect(sent_headers["Authorization"]).to eq("Discogs token=secret")
    end
  end

  it "turns network failures into transient errors" do
    allow(discogs).to receive(:request).and_call_original
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

    expect { discogs.master(1) }.to raise_error(described_class::TransientError, /Net::OpenTimeout/)
  end
end
