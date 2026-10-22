class Point < ApplicationRecord
  belongs_to :user
  belongs_to :chat
  # Set when a member gave it by replying with a number (Response::Reply);
  # nil for RPS results, bugging fees and points from before the budget.
  belongs_to :giver, class_name: "User", optional: true
  # Set when it's the reward for a coffee or a push-up set.
  belongs_to :activity, optional: true, inverse_of: :reward

  validates :amount, numericality: { only_integer: true, other_than: 0 }
end
