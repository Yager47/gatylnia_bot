module Achievements
  # One release, as the "period" of an achievement decided per release:
  # key "release-123".
  ReleasePeriod = Data.define(:release_id) do
    def key
      "release-#{release_id}"
    end
  end
end
