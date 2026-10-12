module Camerton
  # Fills in a pending release's artist and title from its platform.
  class ReleaseResolver
    def initialize(release, cleaner: nil)
      @release = release
      @cleaner = cleaner
    end

    # Does nothing unless the release is pending, so a retry or a second job
    # for the same release doesn't pay for another lookup.
    def call
      return unless @release.pending?

      source = Links.platform(@release.platform).source_metadata(@release)
      return @release.update!(status: :unresolvable) unless source

      name = cleaner.call(kind: @release.kind, source: source)
      @release.update!(
        status: :resolved,
        artist: name.artist.presence,
        title: name.title.presence || source.title,
        source_title: source.title,
        source_author: source.author
      )
    end

    private

    def cleaner
      @cleaner ||= ReleaseNameCleaner.new
    end
  end
end
