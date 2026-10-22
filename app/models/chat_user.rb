class ChatUser < ApplicationRecord
  MAX_PSEUDONYM = 32

  belongs_to :chat
  belongs_to :user

  # Bought with Response::Pseudonym, shown through MemberNames.
  normalizes :pseudonym, with: ->(pseudonym) { pseudonym.squish.presence }
  validates :pseudonym, length: { maximum: MAX_PSEUDONYM }, allow_nil: true
  validates :pseudonym_key, uniqueness: { scope: :chat_id }, allow_nil: true

  # pseudonym_key is the lowercased pseudonym, unique per chat. Lowercased in
  # Ruby: LOWER() in a C-locale database leaves Cyrillic as it is.
  def pseudonym=(value)
    super
    self.pseudonym_key = pseudonym&.downcase
  end
end
