# The chat's points go by "жмихкоїни" in replies. They're stored as plain
# integers in Point#amount; this only names them.
module Zhmykhcoins
  module_function

  # 1 => "1 жмихкоїн", 3 => "3 жмихкоїни", 5 or 11 => "5 жмихкоїнів".
  # signed: true writes gains as "+50".
  def count(amount, signed: false)
    number = signed ? format("%+d", amount) : amount.to_s
    "#{number} #{Plural.word(amount, 'жмихкоїн', 'жмихкоїни', 'жмихкоїнів')}"
  end

  def balance(user, chat)
    chat.points.where(user: user).sum(:amount)
  end

  # Takes fee from the user's balance in chat as a Point, or returns nil when
  # the balance doesn't cover it: purchases never go below zero. Locks the
  # user's row so two purchases at once can't both pass the check.
  def spend(user, chat, fee, reason:)
    user.with_lock do
      next if balance(user, chat) < fee

      user.points.create!(chat: chat, amount: -fee, reason: reason)
    end
  end

  def affordable?(user, chat, fee)
    balance(user, chat) >= fee
  end

  # The refusal when the balance doesn't cover a purchase.
  def not_enough(user, chat, fee)
    "Це коштує #{count(fee)}, а в тебе #{count(balance(user, chat))}. Спершу назбирай."
  end
end
