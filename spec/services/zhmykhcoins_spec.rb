require "rails_helper"

RSpec.describe Zhmykhcoins do
  it "picks the Ukrainian plural form" do
    expect([ 1, 21, 2, 4, 22, 5, 11, 12, 14, 20, 111, 500 ].map { |n| described_class.count(n) }).to eq([
      "1 жмихкоїн", "21 жмихкоїн", "2 жмихкоїни", "4 жмихкоїни", "22 жмихкоїни", "5 жмихкоїнів",
      "11 жмихкоїнів", "12 жмихкоїнів", "14 жмихкоїнів", "20 жмихкоїнів", "111 жмихкоїнів", "500 жмихкоїнів"
    ])
  end

  it "signs the amount on request, picking the form by its absolute value" do
    expect(described_class.count(21, signed: true)).to eq("+21 жмихкоїн")
    expect(described_class.count(-21, signed: true)).to eq("-21 жмихкоїн")
    expect(described_class.count(-3)).to eq("-3 жмихкоїни")
  end
end
