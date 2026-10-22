module Camerton
  # Everyone's opinion of one release in the chat, best first:
  #   🎵 Queen — Bohemian Rhapsody · пісня
  #   Середня 7.7 · 3 оцінки
  #   Вперше скинув Петро 12.03.2026, всього 2 рази
  #
  #   Іван: 9 🔥 — каже, що це шедевр
  # Four queries however many reviews there are.
  class ReleaseCard
    def initialize(share)
      @share = share
      @chat = share.chat
      @release = share.release
    end

    def text
      reviews = Review.where(chat: @chat, release: @release).where.not(score: nil)
        .includes(:user).order(score: :desc, scored_at: :asc).to_a

      [ heading(reviews), history, "", *review_lines(reviews) ].join("\n").strip
    end

    private

    def heading(reviews)
      title = "#{Formatting.release(@release)} · #{Formatting.kind(@release)}"
      return "#{title}\nОцінок ще нема." if reviews.empty?

      average = reviews.sum(&:score).fdiv(reviews.size)
      "#{title}\nСередня #{Formatting.score(average)} · #{Plural.count(reviews.size, 'оцінка', 'оцінки', 'оцінок')}"
    end

    def history
      shares = @chat.release_shares.where(release: @release)
      first = shares.includes(:user).order(:shared_at, :id).first
      total = shares.count
      times = total > 1 ? ", всього #{Plural.count(total, 'раз', 'рази', 'разів')}" : ""

      "Вперше скинув #{first.user.name} #{first.shared_at.strftime('%d.%m.%Y')}#{times}"
    end

    def review_lines(reviews)
      reviews.map do |review|
        line = "#{review.user.name}: #{review.score} #{ReviewReaction::EMOJIS.fetch(review.label)}"
        review.summary.present? ? "#{line} — #{review.summary}" : line
      end
    end
  end
end
