module TelegramExport
  # Reads a Telegram Desktop HTML chat export (messages.html, messages2.html, …)
  # and yields its regular messages in chronological order.
  #
  # The HTML has no sender ids or time zone, so:
  # - the sender's Telegram id comes from their userpic file name
  #   (photos/author_<id>.jpg); senders without a photo get a nil id;
  # - "joined" messages (several in a row by one sender) carry no sender at
  #   all and inherit it from the message before;
  # - dates are written in the local time of the computer that made the
  #   export, so they're parsed in the app's time zone.
  #
  # reply_to_message_id is the id of the message replied to, and link_urls
  # the targets of the links in the text (a link can hide behind any words).
  class HtmlParser
    Message = Data.define(:telegram_message_id, :sender_id, :sender_name, :sent_at, :text, :reply_to_message_id, :link_urls) do
      def initialize(reply_to_message_id: nil, link_urls: [], **attributes)
        super
      end
    end

    # "#go_to_message123", or "messages2.html#go_to_message123" across files.
    REPLY_TARGET = /go_to_message(\d+)/

    MONTHS = %w[січня лютого березня квітня травня червня липня серпня вересня жовтня листопада грудня].freeze
    DATE = /\A(\d{1,2}) (\S+) (\d{4}), (\d{2}):(\d{2}):(\d{2})\z/

    def initialize(dir)
      @dir = Pathname(dir)
    end

    def each_message(&block)
      return enum_for(:each_message) unless block

      sender = {}
      files.each { |file| parse_file(file, sender, &block) }
    end

    private

    # messages.html, messages2.html, … messages10.html: sort by number, not name.
    def files
      paths = @dir.glob("messages*.html")
      raise ArgumentError, "No messages*.html in #{@dir}" if paths.empty?

      paths.sort_by { |path| path.basename.to_s[/\d+/].to_i }
    end

    # `sender` carries the last sender over to the next file, in case one starts
    # with a "joined" message.
    def parse_file(file, sender)
      Nokogiri::HTML(file.read).css("div.message.default").each do |node|
        unless node.classes.include?("joined")
          sender[:name] = node.at_css(".from_name")&.text&.strip
          sender[:id] = node.at_css("img.userpic")&.[]("src").to_s[/author_(\d+)\./, 1]
        end

        yield Message.new(
          telegram_message_id: node["id"].delete_prefix("message").to_i,
          sender_id: sender[:id],
          sender_name: sender[:name],
          sent_at: parse_time(node.at_css(".date.details")["title"]),
          text: text_of(node),
          reply_to_message_id: node.at_css(".reply_to a")&.[]("href").to_s[REPLY_TARGET, 1]&.to_i,
          link_urls: node.css(".text a[href]").map { |link| link["href"] }
        )
      end
    end

    # Matches the Bot API `text`: links become their visible text, <br> a newline.
    def text_of(node)
      text = node.at_css(".text") or return
      text.css("br").each { |br| br.replace("\n") }
      text.text.strip
    end

    def parse_time(title)
      day, month, year, hour, min, sec = title.match(DATE)&.captures
      raise ArgumentError, "Unknown date format: #{title.inspect}" unless day && MONTHS.include?(month)

      Time.zone.local(year.to_i, MONTHS.index(month) + 1, day.to_i, hour.to_i, min.to_i, sec.to_i)
    end
  end
end
