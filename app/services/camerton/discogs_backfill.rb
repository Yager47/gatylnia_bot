module Camerton
  # Asks Discogs about releases that never were: the history import resolved
  # them without DiscogsDetails. Paced to the rate limit (two requests a
  # release); a failed release stays unchecked for the next run, so it's
  # safe to stop and run again.
  class DiscogsBackfill
    REQUESTS_PER_RELEASE = 2
    # Discogs counts requests over a moving minute: after a 429 or another
    # failure, a full minute lets the window clear.
    FAILURE_PAUSE = 60 # seconds

    Report = Data.define(:matched, :unmatched, :failed)

    def self.releases
      Release.resolved.where(merged_into_id: nil, discogs_checked_at: nil).where.not(artist: [ nil, "" ])
    end

    def initialize(discogs: Discogs.new, sleeper: ->(seconds) { sleep(seconds) }, output: $stdout)
      @discogs = discogs
      @sleeper = sleeper
      @output = output
    end

    def pause
      60.0 / @discogs.requests_per_minute * REQUESTS_PER_RELEASE
    end

    def call
      counts = Hash.new(0)

      self.class.releases.find_each do |release|
        DiscogsDetails.new(release, discogs: @discogs).call
        outcome = outcome(release)
        counts[outcome] += 1
        @output.puts "#{release.id} #{Formatting.release(release)}: #{describe(release, outcome)}"
        @sleeper.call(outcome == :failed ? FAILURE_PAUSE : pause)
      end

      Report.new(matched: counts[:matched], unmatched: counts[:unmatched], failed: counts[:failed])
    end

    private

    def outcome(release)
      if release.discogs_checked_at.nil? then :failed
      elsif release.discogs_master_id then :matched
      else :unmatched
      end
    end

    def describe(release, outcome)
      case outcome
      when :failed then "failed, left for the next run"
      when :unmatched then "no match"
      else [ *release.genres, *release.styles ].join(", ").presence || "matched, no genres"
      end
    end
  end
end
