class ReviewScoreChange < ApplicationRecord
  belongs_to :review

  validates :from_score, :to_score, :changed_at, presence: true
end
