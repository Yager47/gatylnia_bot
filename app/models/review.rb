class Review < ApplicationRecord
  # Score ranges shown as words; also picks the bot's reaction to a review.
  LABELS = { bad: 1..3, mid: 4..5, good: 6..8, great: 9..10 }.freeze

  belongs_to :chat
  belongs_to :release
  belongs_to :user
  has_many :messages, class_name: "ReviewMessage", dependent: :destroy

  # Nil until scored, and when nothing said so far is about the music.
  validates :score, numericality: { only_integer: true, in: 1..10 }, allow_nil: true

  # :bad, :mid, :good or :great; nil without a score.
  def label
    LABELS.find { |_label, range| range.cover?(score) }&.first if score
  end
end
