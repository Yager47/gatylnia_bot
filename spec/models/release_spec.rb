require "rails_helper"

RSpec.describe Release do
  it "is unique per platform and external id at the database level" do
    create(:release, external_id: "lYBUbBu4W08")

    expect { described_class.new(platform: "youtube_music", external_id: "lYBUbBu4W08", kind: :song, url: "x").save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "can't be deleted while it has shares" do
    share = create(:release_share)

    expect { share.release.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
