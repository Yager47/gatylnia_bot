require "rails_helper"

RSpec.describe OpenAiClient do
  it "raises when OPENAI_API_KEY is missing" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("OPENAI_API_KEY").and_raise(KeyError)

    expect { described_class.build }.to raise_error(KeyError)
  end
end
