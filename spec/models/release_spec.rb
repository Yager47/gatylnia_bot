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

  describe ".with_genre" do
    it "matches a substring of a genre or style in any case, and never releases without them" do
      rock = create(:release, genres: [ "Rock" ], styles: [ "Post-Punk" ])
      post_rock = create(:release, genres: [ "Electronic" ], styles: [ "Post-Rock" ])
      styles_only = create(:release, genres: nil, styles: [ "Punk Rock" ])
      jazz = create(:release, genres: [ "Jazz" ], styles: [])
      create(:release, genres: nil, styles: nil)

      expect(described_class.with_genre("rock")).to contain_exactly(rock, post_rock, styles_only)
      expect(described_class.with_genre("POST-PUNK")).to contain_exactly(rock)
      expect(described_class.with_genre("jazz")).to contain_exactly(jazz)
    end

    it "treats LIKE wildcards in the text literally" do
      create(:release, genres: [ "Rock" ])

      expect(described_class.with_genre("%")).to be_empty
      expect(described_class.with_genre("r_ck")).to be_empty
    end
  end
end
