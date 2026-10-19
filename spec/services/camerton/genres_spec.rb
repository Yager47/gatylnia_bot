require "rails_helper"

RSpec.describe Camerton::Genres do
  let(:chat) { create(:chat, camerton_enabled: true) }

  def text
    described_class.new(chat: chat).text
  end

  def shared(genres, styles: nil, chat: self.chat)
    create(:release_share, chat: chat, release: create(:release, genres: genres, styles: styles)).release
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  it "counts the chat's releases per genre, most first, then by name" do
    rock_and_pop = shared(%w[Rock Pop])
    create(:release_share, chat: chat, release: rock_and_pop) # a re-share counts once
    shared(%w[Rock])
    shared(%w[Jazz])
    shared(%w[Electronic])
    shared(%w[Hip\ Hop], chat: create(:chat))

    expect(text).to eq(<<~TEXT.chomp)
      🎸 Жанри наших релізів:

      Rock: 2 релізи
      Electronic: 1 реліз
      Jazz: 1 реліз
      Pop: 1 реліз
    TEXT
  end

  it "adds how many releases Discogs gave no genre" do
    shared(%w[Rock])
    shared(nil)
    shared([])

    expect(text).to end_with("Rock: 1 реліз\n\nБез жанру: 2 релізи")
  end

  it "lists the styles after the genres, the same way" do
    shared(%w[Rock], styles: %w[Shoegaze Post-Rock])
    shared(%w[Rock], styles: %w[Shoegaze])
    shared(%w[Jazz], styles: %w[Shoegaze], chat: create(:chat))

    expect(text).to end_with("Rock: 2 релізи\n\n🎛 Стилі:\n\nShoegaze: 2 релізи\nPost-Rock: 1 реліз")
  end

  it "lists only the top styles, so the message stays under Telegram's limit" do
    stub_const("#{described_class}::STYLES_SHOWN", 2)
    shared(%w[Rock], styles: %w[A B C D E F])
    shared(%w[Rock], styles: %w[B])

    expect(text).to end_with("🎛 Стилі:\n\nB: 2 релізи\nA: 1 реліз\nі ще 4 стилі")
  end

  it "says so when no release has a genre" do
    shared(nil)

    expect(text).to eq("🎸 Жанри:\n\nЩе нема релізів із жанром з Discogs.")
  end

  it "runs the same number of queries however many releases there are" do
    shared(%w[Rock])
    queries = count_queries { text }

    3.times { |i| shared([ "Genre #{i}", "Rock" ], styles: [ "Style #{i}" ]) }
    shared(nil)

    expect(count_queries { text }).to eq(queries)
  end

  it "answers @bot жанри" do
    shared(%w[Rock])

    expect(Camerton::StatsCommand.new(command: "жанри", chat: chat).call).to eq(text)
  end
end
