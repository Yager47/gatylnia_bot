# Responders decide whether and how the bot answers a message. Each #call
# returns one of:
#   a String - reply with it; no later responder runs
#   Threaded - the same, sent as a reply to a given Telegram message
#   Html     - the same, as Telegram HTML (links, mentions)
#   STOP     - don't reply, and no later responder runs either
#   nil      - not mine; let the next responder try
module Response
  STOP = :stop

  # text, answering the Telegram message with id reply_to.
  Threaded = Data.define(:text, :reply_to)

  # text in Telegram HTML; the responder escapes everything that isn't markup.
  Html = Data.define(:text)

  # Whether an outcome is something to send (see ChatModeHandler#deliver).
  def self.answer?(outcome)
    outcome.is_a?(String) || outcome.is_a?(Threaded) || outcome.is_a?(Html)
  end

  # Calls the responders (lambdas, so later ones aren't even built) in order
  # and returns the first non-nil outcome, or nil if none answered.
  def self.first(responders)
    responders.each do |responder|
      outcome = responder.call
      return outcome unless outcome.nil?
    end

    nil
  end
end
