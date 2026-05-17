class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :user, optional: true
  belongs_to :reply_to, class_name: "Message", optional: true
  has_many :replies, class_name: "Message", foreign_key: :reply_to_id, dependent: :nullify, inverse_of: :reply_to

  enum :role, {
    user: 0,
    assistant: 1
  }

  validates :role, presence: true

  def ai_context
    parts = []
    parts << reply_prefix if reply_prefix.present?
    parts << reactions_prefix if reactions_prefix.present?
    parts << body
    parts.join("\n")
  end

  private

  def body
    if role == "user"
      "#{user&.name || 'Хтось'}: \"#{content}\""
    else
      "\"#{content}\""
    end
  end

  def reply_prefix
    if reply_to.present?
      target = reply_to.user&.name || "бот"
      quoted = reply_to.content.to_s.truncate(200)
      "[відповідь #{user&.name || 'Хтось'} → #{target}: \"#{quoted}\"]"
    elsif reply_snapshot.present?
      snapshot = reply_snapshot.with_indifferent_access
      target = snapshot[:user_name] || "хтось"
      quoted = snapshot[:content].to_s.truncate(200)
      "[відповідь #{user&.name || 'Хтось'} → #{target}: \"#{quoted}\"]"
    end
  end

  def reactions_prefix
    lines = reaction_lines
    return if lines.empty?

    "[реакції: #{lines.join(', ')}]"
  end

  def reaction_lines
    data = reactions.with_indifferent_access
    lines = []

    users = data[:users]
    if users.is_a?(Hash)
      users.each_value do |info|
        name = info["name"] || "хтось"
        Array(info["emojis"]).each { |emoji| lines << "#{emoji} #{name}" }
      end
    end

    totals = data[:totals]
    if totals.is_a?(Hash)
      totals.each do |emoji, count|
        next if lines.any? { |line| line.start_with?(emoji.to_s) }

        lines << "#{emoji} ×#{count}"
      end
    end

    lines
  end
end
