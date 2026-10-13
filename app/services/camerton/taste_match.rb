module Camerton
  # How closely two members' scores agree on releases both of them scored:
  # 100% when the scores are identical, 0% when every pair is 1 vs 10.
  class TasteMatch
    # A twin needs enough releases in common to mean anything.
    MIN_COMMON_FOR_TWIN = 3
    MAX_GAP = 9.0 # 10 - 1

    # [[other_user_id, common releases, agreement %], ...], closest first.
    # One query however many members and reviews there are.
    def self.agreements(chat:, user:, other: nil, min_common: MIN_COMMON_FOR_TWIN)
      pairs = pairs(chat, user)
      pairs = pairs.where(others: { user_id: other.id }) if other

      pairs.group("others.user_id")
        .having("COUNT(*) >= ?", min_common)
        .order(Arel.sql("AVG(ABS(reviews.score - others.score)), COUNT(*) DESC, others.user_id"))
        .pluck(Arel.sql("others.user_id"), Arel.sql("COUNT(*)"), Arel.sql("AVG(ABS(reviews.score - others.score))"))
        .map { |other_id, common, gap| [ other_id, common, agreement(gap) ] }
    end

    # The user's scored reviews joined with other members' scores of the
    # same releases in the same chat.
    def self.pairs(chat, user)
      Review.where(chat: chat, user: user).where.not(score: nil)
        .joins("JOIN reviews others ON others.chat_id = reviews.chat_id AND others.release_id = reviews.release_id " \
               "AND others.user_id <> reviews.user_id AND others.score IS NOT NULL")
    end

    def self.agreement(gap)
      (100 * (1 - gap.to_f / MAX_GAP)).round
    end

    def initialize(chat:, user:, other:)
      @chat = chat
      @user = user
      @other = other
    end

    # "@bot смак з @нік". Three queries.
    def text
      names = "#{@user.name} і #{@other.name}"
      _other_id, common, agreement = self.class.agreements(chat: @chat, user: @user, other: @other, min_common: 1).first
      return "🤝 #{names}: спільних оцінок ще нема." unless common

      [
        "🤝 #{names}: збіг #{agreement}% на #{Formatting.count(common, 'спільному релізі', 'спільних релізах', 'спільних релізах')}",
        *biggest_gap
      ].join("\n")
    end

    private

    def biggest_gap
      mine, theirs, release_id = self.class.pairs(@chat, @user).where(others: { user_id: @other.id })
        .order(Arel.sql("ABS(reviews.score - others.score) DESC, reviews.release_id"))
        .pick(:score, Arel.sql("others.score"), :release_id)
      return [] if mine == theirs

      [ "Найбільше розійшлися: #{Formatting.release(Release.find(release_id))} (#{mine} проти #{theirs})" ]
    end
  end
end
