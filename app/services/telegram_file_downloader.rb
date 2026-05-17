require "net/http"
require "uri"

class TelegramFileDownloader
  def self.download(file_id)
    client = Telegram::Bot::Client.new(ENV.fetch("TELEGRAM_BOT_API_TOKEN"))
    response = client.api.get_file(file_id: file_id)
    remote_path = extract_file_path(response)
    raise "Telegram file path missing" if remote_path.blank?

    download_from_telegram(remote_path)
  end

  def self.extract_file_path(response)
    return response.file_path if response.respond_to?(:file_path)

    payload = response.is_a?(Hash) ? response : response.to_h
    payload.dig("result", "file_path") || payload["file_path"]
  end
  private_class_method :extract_file_path

  def self.download_from_telegram(remote_path)
    url = URI("https://api.telegram.org/file/bot#{ENV.fetch('TELEGRAM_BOT_API_TOKEN')}/#{remote_path}")
    ext = File.extname(remote_path).presence || ".mp4"
    temp = Tempfile.new(["telegram", ext])
    temp.binmode

    Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
      request = Net::HTTP::Get.new(url)
      http.request(request) do |response|
        raise "Telegram file download failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.read_body { |chunk| temp.write(chunk) }
      end
    end

    temp.close
    temp.path
  end
  private_class_method :download_from_telegram
end
