class Release < ApplicationRecord
  has_many :shares, class_name: "ReleaseShare", dependent: :restrict_with_exception
  has_many :reviews, dependent: :restrict_with_exception

  enum :kind, { song: 0, album: 1 }, validate: true

  # unresolvable: the platform has no metadata for it (deleted, private, or
  # not embeddable). It can still be shared and reviewed.
  enum :status, { pending: 0, resolved: 1, unresolvable: 2 }, validate: true

  # No uniqueness validation: the unique index on [platform, external_id]
  # enforces it, and creation goes through create_or_find_by!.
  validates :platform, :external_id, :url, presence: true
end
