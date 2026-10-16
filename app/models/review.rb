class Review < ApplicationRecord
  # Score ranges shown as words; also picks the bot's reaction to a review.
  LABELS = { bad: 1..3, mid: 4..5, good: 6..8, great: 9..10 }.freeze

  belongs_to :chat
  belongs_to :release
  belongs_to :user
  has_many :messages, class_name: "ReviewMessage", dependent: :destroy

  # telegram: scored from replies in the chat. spreadsheet: a score from a
  # member's ratings file (Camerton::RatingsImport), usually with no messages.
  enum :source, { telegram: 0, spreadsheet: 1 }, validate: true

  # Nil until scored, and when nothing said so far is about the music.
  validates :score, numericality: { only_integer: true, in: 1..10 }, allow_nil: true

  # :bad, :mid, :good or :great; nil without a score.
  def label
    LABELS.find { |_label, range| range.cover?(score) }&.first if score
  end
end
