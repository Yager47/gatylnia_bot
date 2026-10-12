require "rails_helper"

RSpec.describe Review do
  it "allows no score or a score from 1 to 10" do
    expect(build(:review, score: nil)).to be_valid
    expect(build(:review, score: 1)).to be_valid
    expect(build(:review, score: 10)).to be_valid
    expect(build(:review, score: 0)).not_to be_valid
    expect(build(:review, score: 11)).not_to be_valid
  end

  it "labels scores: 1-3 bad, 4-5 mid, 6-8 good, 9-10 great" do
    labels = (1..10).to_h { |score| [ score, build(:review, score: score).label ] }

    expect(labels).to eq(
      1 => :bad, 2 => :bad, 3 => :bad, 4 => :mid, 5 => :mid,
      6 => :good, 7 => :good, 8 => :good, 9 => :great, 10 => :great
    )
    expect(build(:review, score: nil).label).to be_nil
  end

  it "enforces the score range in the database too" do
    review = create(:review)

    expect { review.update_column(:score, 11) }.to raise_error(ActiveRecord::StatementInvalid, /reviews_score_range/)
  end

  it "is unique per chat, release and user in the database" do
    review = create(:review)

    expect { described_class.new(review.attributes.slice("chat_id", "release_id", "user_id")).save!(validate: false) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
