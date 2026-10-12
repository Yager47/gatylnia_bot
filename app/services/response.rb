# Responders decide whether and how the bot answers a message. Each #call
# returns one of:
#   a String - reply with it; no later responder runs
#   STOP     - don't reply, and no later responder runs either
#   nil      - not mine; let the next responder try
module Response
  STOP = :stop

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
