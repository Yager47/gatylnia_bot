RSpec.configure do |config|
  config.before do
    # Fail loudly if a spec reaches YouTube without stubbing it explicitly.
    allow_any_instance_of(Camerton::YoutubeOembed).to receive(:request).and_raise("Unstubbed YouTube oEmbed request in spec")
  end
end
