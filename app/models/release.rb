class Release < ApplicationRecord
  has_many :shares, class_name: "ReleaseShare", dependent: :restrict_with_exception
  has_many :reviews, dependent: :restrict_with_exception

  # Set when another link turned out to be the same song or album
  # (Camerton::ReleaseMerge): this row then only maps its link to that one.
  belongs_to :merged_into, class_name: "Release", optional: true

  enum :kind, { song: 0, album: 1 }, validate: true

  # unresolvable: the platform has no metadata for it (deleted, private, or
  # not embeddable). It can still be shared and reviewed.
  enum :status, { pending: 0, resolved: 1, unresolvable: 2 }, validate: true

  # No uniqueness validation: the unique index on [platform, external_id]
  # enforces it, and creation goes through create_or_find_by!.
  validates :platform, :external_id, :url, presence: true

  # The release a Camerton::Link points to, created pending if new. Safe when
  # two jobs see the same new link at once (create_or_find_by!).
  def self.find_or_create_for(link)
    release = find_by(platform: link.platform, external_id: link.external_id) ||
      create_or_find_by!(platform: link.platform, external_id: link.external_id) do |new_release|
        new_release.kind = link.kind
        new_release.url = link.url
      end

    release.canonical
  end

  # The release a Camerton::Link points to, or nil if it was never shared.
  def self.find_for(link)
    find_by(platform: link.platform, external_id: link.external_id)&.canonical
  end

  # The release shares and reviews are kept under: the one this was merged
  # into, or itself. Merges never chain, so one step is enough.
  def canonical
    merged_into || self
  end
end
