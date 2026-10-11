require "rails_helper"

RSpec.describe TelegramFileDownloader do
  around do |example|
    Dir.mktmpdir { |dir| @dir = dir; example.run }
  end

  # Net::HTTP without a network: the response streams the given chunks.
  def stub_download(response: Net::HTTPOK.new("1.1", "200", "OK"), chunks: [ "vid", "eo" ])
    allow(response).to receive(:read_body) { |&block| chunks.each(&block) }
    http = double("http")
    allow(http).to receive(:request) { |_request, &block| block.call(response) }
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  it "writes the file into the given dir and returns its path" do
    stub_download

    path = described_class.download("abc", dir: @dir)

    expect(path).to eq(File.join(@dir, "telegram.mp4"))
    expect(File.binread(path)).to eq("video")
    expect(fake_telegram.calls).to include([ :get_file, { file_id: "abc" } ])
    expect(Net::HTTP).to have_received(:start).with("api.telegram.org", 443, use_ssl: true)
  end

  it "raises when Telegram answers with an error" do
    stub_download(response: Net::HTTPNotFound.new("1.1", "404", "Not Found"))

    expect { described_class.download("abc", dir: @dir) }.to raise_error("Telegram file download failed: 404")
  end
end
