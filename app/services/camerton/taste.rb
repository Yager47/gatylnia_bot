module Camerton
  # "@bot мій смак": one member's scores in the chat, favourites and least
  # favourites, and whose taste is closest. Seven queries however many
  # reviews there are.
  class Taste
    SHOWN = 10
    # Favourites are good or great reviews; the least liked, bad or mid ones.
    LIKED = Review::LABELS[:good].min..Review::LABELS[:great].max
    DISLIKED = Review::LABELS[:bad].min..Review::LABELS[:mid].max

    def initialize(chat:, user:)
      @chat = chat
      @user = user
      @reviews = Review.where(chat: chat, user: user).where.not(score: nil)
    end

    def text
      count, average = @reviews.pick(Arel.sql("COUNT(*)"), Arel.sql("AVG(score)"))
      return "🎧 #{@user.name}: оцінок ще нема." if count.zero?

      favourites = @reviews.where(score: LIKED).order(score: :desc, scored_at: :desc, id: :desc).includes(:release).limit(SHOWN).to_a
      least = @reviews.where(score: DISLIKED).order(:score, scored_at: :desc, id: :desc).includes(:release).limit(SHOWN).to_a

      [
        "🎧 Смак: #{@user.name}",
        "#{Formatting.count(count, 'оцінка', 'оцінки', 'оцінок')}, середня #{Formatting.score(average)}",
        *release_section("Найбільше зайшло:", favourites),
        *release_section("Найменше зайшло:", least),
        *twin_lines
      ].join("\n")
    end

    private

    def release_section(title, reviews)
      return [] if reviews.empty?

      [ "", title, *reviews.map { |review| "#{Formatting.release(review.release)} · #{review.score}" } ]
    end

    def twin_lines
      user_id, common, agreement = TasteMatch.agreements(chat: @chat, user: @user).first
      return [] unless user_id

      [ "", "Найближчий смак: #{User.find(user_id).name} (збіг #{agreement}% на #{Formatting.count(common, 'спільному релізі', 'спільних релізах', 'спільних релізах')})" ]
    end
  end
end
