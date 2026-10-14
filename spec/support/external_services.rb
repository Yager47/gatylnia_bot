RSpec.configure do |config|
  config.before do
    # Fail loudly if a spec reaches YouTube or Discogs without stubbing it explicitly.
    allow_any_instance_of(Camerton::YoutubeOembed).to receive(:request).and_raise("Unstubbed YouTube oEmbed request in spec")
    allow_any_instance_of(Camerton::Discogs).to receive(:request).and_raise("Unstubbed Discogs request in spec")
  end
end
