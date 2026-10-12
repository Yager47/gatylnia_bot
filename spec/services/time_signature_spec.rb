require "rails_helper"

RSpec.describe TimeSignature do
  it "returns a random time signature" do
    expect(described_class.call).to match(%r{\A\d+/(4|8|16)\z})
  end

  it "exposes only .call" do
    expect(described_class.singleton_methods(false)).to eq([ :call ])
  end
end
