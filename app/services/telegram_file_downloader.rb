require "net/http"
require "uri"

class TelegramFileDownloader
  class Error < StandardError; end

  # Downloads a Telegram file into `dir` and returns its path. The caller owns
  # `dir` and removes it. (A closed Tempfile's path isn't safe to return: the
  # file is deleted when the Tempfile object is garbage-collected.)
  def self.download(file_id, dir:)
    response = TelegramClient.build.api.get_file(file_id: file_id)
    remote_path = extract_file_path(response)
    raise Error, "Telegram file path missing" if remote_path.blank?

    download_from_telegram(remote_path, dir)
  end

  def self.extract_file_path(response)
    return response.file_path if response.respond_to?(:file_path)

    payload = response.is_a?(Hash) ? response : response.to_h
    payload.dig("result", "file_path") || payload["file_path"]
  end
  private_class_method :extract_file_path

  def self.download_from_telegram(remote_path, dir)
    url = URI("https://api.telegram.org/file/bot#{ENV.fetch('TELEGRAM_BOT_API_TOKEN')}/#{remote_path}")
    path = File.join(dir, "telegram#{File.extname(remote_path).presence || '.mp4'}")

    File.open(path, "wb") do |file|
      Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(url)) do |response|
          raise Error, "Telegram file download failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          response.read_body { |chunk| file.write(chunk) }
        end
      end
    end

    path
  end
  private_class_method :download_from_telegram
end
