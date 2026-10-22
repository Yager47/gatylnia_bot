require "rails_helper"

RSpec.describe "Camerton people stats" do
  let(:chat) { create(:chat, camerton_enabled: true) }

  def member(name, username: nil)
    create(:user, first_name: name, last_name: nil, username: username, chats: [ chat ])
  end

  def release(title)
    create(:release, :resolved, artist: "Artist", title: title)
  end

  def scores(user, by_release)
    by_release.each { |release, score| create(:review, chat: chat, release: release, user: user, score: score, scored_at: Time.current) }
  end

  def command(text, user: nil)
    Camerton::StatsCommand.new(command: text, chat: chat, user: user).call
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  let(:a) { release("A") }
  let(:b) { release("B") }
  let(:c) { release("C") }
  let(:d) { release("D") }

  describe "критики" do
    it "lists members from the harshest, and names the extremes among those with 3+ scores" do
      scores(member("Іван"), a => 3, b => 5, c => 4)
      scores(member("Оля"), a => 9, b => 8, c => 10)
      scores(member("Марко"), a => 1)
      create(:review, chat: chat, release: d, user: member("Тихий"), score: nil)
      create(:review, release: a, user: member("Чужий"), score: 1) # another chat

      expect(command("критики")).to eq(<<~TEXT.strip)
        🧐 Критики (від найсуворіших):

        Марко: 1 оцінка, середня 1
        Іван: 3 оцінки, середня 4
        Оля: 3 оцінки, середня 9

        Найсуворіші оцінки: Іван (4)
        Найщедріші оцінки: Оля (9)
      TEXT
    end

    it "says when nobody has scored anything" do
      expect(command("критики")).to eq("🧐 Критики:\n\nЩе ніхто нічого не оцінив.")
    end

    it "runs the same number of queries however many members there are" do
      scores(member("Іван"), a => 5)
      queries_for_one = count_queries { command("критики") }

      3.times { |index| scores(member("Member #{index}"), a => 7, b => 8) }
      chat.reload # drops the cached pseudonyms (Chat#member_names), as a new update would

      expect(count_queries { command("критики") }).to eq(queries_for_one)
    end
  end

  describe "камертони" do
    it "ranks sharers by the average score of what they shared, the sharer's own score included" do
      petro = member("Петро")
      olya = member("Оля")
      ivan = member("Іван")
      create(:release_share, chat: chat, release: a, user: petro)
      create(:release_share, chat: chat, release: a, user: petro) # a re-share counts once
      create(:release_share, chat: chat, release: b, user: petro)
      create(:release_share, chat: chat, release: c, user: olya)
      create(:release_share, chat: chat, release: d, user: ivan)
      scores(petro, a => 10)
      scores(olya, a => 6, b => 5, c => 9)
      create(:release_share, release: c, user: olya) # another chat
      create(:review, release: a, score: 1) # a score of A from another chat

      expect(command("камертони")).to eq(<<~TEXT.strip)
        🎛 Камертони (чиї релізи заходять найкраще):

        Оля: 1 реліз, середня 9 (1 оцінка)
        Петро: 2 релізи, середня 7 (3 оцінки)
        Іван: 1 реліз, оцінок ще нема
      TEXT
    end

    it "says when nobody has shared anything" do
      expect(command("камертони")).to eq("🎛 Камертони:\n\nЩе ніхто нічого не скинув.")
    end

    describe "a release every member scored as bad" do
      let(:petro) { member("Петро") }
      let(:olya) { member("Оля") }
      let!(:ivan) { member("Іван") } # a member from the start, scored or not

      before do
        create(:release_share, chat: chat, release: a, user: petro)
        create(:release_share, chat: chat, release: b, user: petro)
        scores(olya, b => 8)
      end

      it "is left out of the sharer's stats, and the reply says so" do
        scores(petro, a => 2)
        scores(olya, a => 1)
        scores(ivan, a => 3)

        expect(command("камертони")).to eq(<<~TEXT.strip)
          🎛 Камертони (чиї релізи заходять найкраще):

          Петро: 1 реліз, середня 8 (1 оцінка)

          Без 1 релізу, які не зайшли нікому, навіть тому, хто скинув.
        TEXT
      end

      it "still counts when a member hasn't scored it, or anyone liked it even a little" do
        scores(petro, a => 2)
        scores(olya, a => 1)
        expect(command("камертони")).to include("Петро: 2 релізи, середня 3.7 (3 оцінки)")

        scores(ivan, a => 4)
        expect(command("камертони")).to include("Петро: 2 релізи, середня 3.8 (4 оцінки)")
        expect(command("камертони")).not_to include("Без ")
      end

      it "ignores scores from other chats and from people who aren't members" do
        scores(petro, a => 2)
        scores(olya, a => 1)
        create(:review, release: a, user: ivan, score: 1) # Іван's score in another chat
        create(:review, chat: chat, release: a, user: create(:user), score: 1) # not a member

        expect(command("камертони")).to include("Петро: 2 релізи")
      end
    end

    it "runs the same number of queries however many shares there are" do
      create(:release_share, chat: chat, release: a, user: member("Петро"))
      queries_for_one = count_queries { command("камертони") }

      3.times { |index| create(:release_share, chat: chat, release: release("R#{index}"), user: member("M#{index}")) }
      chat.reload # drops the cached pseudonyms (Chat#member_names), as a new update would

      expect(count_queries { command("камертони") }).to eq(queries_for_one)
    end
  end

  describe "мій смак" do
    let(:me) { member("Петро") }

    it "shows my count, average, favourites, least favourites and closest taste" do
      e = release("E")
      f = release("F")
      g = release("G")
      scores(me, a => 10, b => 9, c => 8, d => 2, e => 4, f => 6, g => 7)
      scores(member("Оля"), a => 9, b => 9, c => 7)
      scores(member("Іван"), a => 2, b => 3, c => 1)
      scores(member("Марко"), a => 10, b => 9) # only two in common: not a twin

      expect(command("мій смак", user: me)).to eq(<<~TEXT.strip)
        🎧 Смак: Петро
        7 оцінок, середня 6.6

        Найбільше зайшло:
        🎵 Artist — A · 10
        🎵 Artist — B · 9
        🎵 Artist — C · 8
        🎵 Artist — G · 7
        🎵 Artist — F · 6

        Найменше зайшло:
        🎵 Artist — D · 2
        🎵 Artist — E · 4

        Найближчий смак: Оля (збіг 93% на 3 спільних релізах)
      TEXT
    end

    it "keeps bad and mid scores out of the favourites, and leaves out a twin without enough in common" do
      scores(me, a => 8, b => 2)
      scores(member("Оля"), a => 8)

      expect(command("мій смак", user: me)).to eq(<<~TEXT.strip)
        🎧 Смак: Петро
        2 оцінки, середня 5

        Найбільше зайшло:
        🎵 Artist — A · 8

        Найменше зайшло:
        🎵 Artist — B · 2
      TEXT
    end

    it "splits at the good/mid boundary and leaves out an empty list" do
      scores(me, a => 6, b => 5)
      expect(command("мій смак", user: me)).to include("Найбільше зайшло:
🎵 Artist — A · 6

Найменше зайшло:
🎵 Artist — B · 5")

      Review.where(user: me, release: b).update_all(score: 9)
      expect(command("мій смак", user: me)).not_to include("Найменше зайшло:")
    end

    it "shows ten releases at most in each list" do
      12.times { |index| scores(me, release("Liked #{index}") => 8) }
      12.times { |index| scores(me, release("Disliked #{index}") => 2) }

      text = command("мій смак", user: me)

      expect(text.scan("Liked ").size).to eq(10)
      expect(text.scan("Disliked ").size).to eq(10)
    end

    it "says when I haven't scored anything" do
      expect(command("мій смак", user: me)).to eq("🎧 Петро: оцінок ще нема.")
    end
  end

  describe "смак з @нік" do
    let(:me) { member("Петро") }

    it "shows the agreement and the release we disagree on most" do
      scores(me, a => 8, b => 9, c => 2)
      scores(member("Оля", username: "OlyaK"), a => 8, b => 7, c => 9)

      expect(command("смак з @olyak", user: me)).to eq(<<~TEXT.strip)
        🤝 Петро і Оля: збіг 67% на 3 спільних релізах
        Найбільше розійшлися: 🎵 Artist — C (2 проти 9)
      TEXT
    end

    it "says 100% without a biggest gap when we always agree" do
      scores(me, a => 8)
      scores(member("Оля", username: "olya"), a => 8)

      expect(command("смак з @olya", user: me)).to eq("🤝 Петро і Оля: збіг 100% на 1 спільному релізі")
    end

    it "says when we have nothing in common, someone isn't in the chat, or it's me" do
      member("Оля", username: "olya")
      me.update!(username: "petro")
      member("Чужий", username: "stranger").chat_users.destroy_all

      expect(command("смак з @olya", user: me)).to eq("🤝 Петро і Оля: спільних оцінок ще нема.")
      expect(command("смак з @nobody", user: me)).to eq("Не знайшов @nobody у цьому чаті.")
      expect(command("смак з @stranger", user: me)).to eq("Не знайшов @stranger у цьому чаті.")
      expect(command("смак з @petro", user: me)).to eq("Із собою збіг завжди 100%.")
    end

    it "isn't a command without a username" do
      expect(command("смак з", user: me)).to be_nil
      expect(command("смак з оля", user: me)).to be_nil
    end
  end

  it "answers all of them through the chat, in any mode" do
    chat.update!(telegram_id: telegram_chat[:id].to_s, mode: :accountant)

    [ "критики", "камертони", "мій смак" ].each_with_index do |word, index|
      TelegramUpdates::Dispatcher.new(message_update(text: "@test_bot #{word}", message_id: 100 + index).deep_stringify_keys).call
    end

    expect(fake_telegram.sent_messages.map { |message| message[:text].lines.first.strip })
      .to eq([ "🧐 Критики:", "🎛 Камертони:", "🎧 Петро Тест: оцінок ще нема." ]) # the sender in telegram_from
  end
end
