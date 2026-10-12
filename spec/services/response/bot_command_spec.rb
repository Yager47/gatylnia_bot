require "rails_helper"

RSpec.describe Response::BotCommand do
  let(:chat) { create(:chat) }
  let(:user) { create(:user, chats: [ chat ]) }

  def stats_for(period)
    described_class.new(user: user, chat: chat, text: "@test_bot гатуни за #{period}").call
  end

  describe "гатуни за ..." do
    it "ranks users by entry count in this chat only" do
      top = create(:user, first_name: "Петро", last_name: nil, chats: [ chat ])
      other = create(:user, first_name: "Ольга", last_name: "Коваль", chats: [ chat ])
      create_list(:entry, 3, chat: chat, user: top)
      create(:entry, chat: chat, user: other)
      create_list(:entry, 5, chat: create(:chat), user: other)

      expect(stats_for("тиждень")).to eq("Гатуни за поточний тиждень:\n\nПетро: 3\nОльга Коваль: 1")
    end

    it "skips users without entries in the period" do
      create(:entry, chat: chat, user: user, created_at: 2.years.ago)

      expect(stats_for("рік")).to eq("Гатуни за поточний рік:\n\n")
    end

    # Production (Heroku) and CI run with a UTC system clock, where Date.today
    # returns the UTC date. Force that here so the spec doesn't depend on the
    # developer machine's time zone; the stats must use the Kyiv calendar day.
    it "uses the Kyiv day, not the server's UTC day" do
      with_system_time_zone("UTC") do
        travel_to Time.utc(2026, 10, 11, 22, 30) do # 01:30 on Oct 12 in Kyiv
          yesterday_user = create(:user, first_name: "Вчорашній", last_name: nil, chats: [ chat ])
          create(:entry, chat: chat, user: user, created_at: Time.zone.local(2026, 10, 12, 0, 30))
          create(:entry, chat: chat, user: yesterday_user, created_at: Time.zone.local(2026, 10, 11, 23, 30))

          expect(stats_for("сьогодні")).to eq("Сьогоднішні гатуни:\n\n#{user.name}: 1")
        end
      end
    end

    it "runs the same number of queries regardless of how many users there are" do
      create(:entry, chat: chat, user: user)
      queries_with_one_user = count_queries { stats_for("місяць") }

      3.times { create(:entry, chat: chat, user: create(:user, chats: [ chat ])) }
      chat.reload # drop associations cached by the first call

      expect(count_queries { stats_for("місяць") }).to eq(queries_with_one_user)
    end
  end

  describe "кава / віджимання за ..." do
    def reply_to(text)
      described_class.new(user: user, chat: chat, text: text).call
    end

    it "replies with activity stats in default mode" do
      create(:activity, chat: chat, user: user)

      expect(reply_to("@test_bot кава за тиждень")).to eq("Кава за поточний тиждень:\n\n#{user.name}: 1")
    end

    it "doesn't reply in accountant mode" do
      chat.update!(mode: :accountant)

      expect(reply_to("@test_bot кава за тиждень")).to be_nil
    end
  end

  describe "баланс" do
    def reply_to(text)
      described_class.new(user: user, chat: chat, text: text).call
    end

    it "ranks every member by their points in this chat, with 0 for none" do
      user.update!(first_name: "Іван", last_name: nil)
      petro = create(:user, first_name: "Петро", last_name: nil, chats: [ chat ])
      create(:user, first_name: "Ольга", last_name: nil, chats: [ chat ])
      Point.create!(chat: chat, user: petro, amount: 30)
      Point.create!(chat: chat, user: petro, amount: -10)
      Point.create!(chat: chat, user: user, amount: -5)
      Point.create!(chat: create(:chat), user: user, amount: 1_000)

      expect(reply_to("@test_bot баланс")).to eq("Загальний баланс в чаті: \n\nПетро: 20\nОльга: 0\nІван: -5")
    end

    it "runs the same number of queries regardless of how many members there are" do
      user # create the lazy chat and user outside the counted block
      queries_with_one_member = count_queries { reply_to("@test_bot баланс") }

      3.times { Point.create!(chat: chat, user: create(:user, chats: [ chat ]), amount: 1) }
      chat.reload

      expect(count_queries { reply_to("@test_bot баланс") }).to eq(queries_with_one_member)
    end

    it "works in accountant mode too" do
      chat.update!(mode: :accountant)

      expect(reply_to("@test_bot баланс")).to start_with("Загальний баланс в чаті:")
    end
  end

  describe "a mention that isn't a command" do
    it "builds no command replies: no queries, no YAML" do
      user
      allow(YAML).to receive(:load_file).and_call_original

      expect(count_queries { described_class.new(user: user, chat: chat, text: "@test_bot як справи").call }).to eq(0)
      expect(YAML).not_to have_received(:load_file)
    end

    it "still answers commands whose replies are lists, picking one" do
      user.update!(username: "ivan")

      expect(described_class.new(user: user, chat: chat, text: "@test_bot пошли мене").call).to start_with("@ivan ")
    end
  end

  describe "command extraction" do
    def reply_to(text)
      described_class.new(user: user, chat: chat, text: text).call
    end

    it "only takes commands that start with the mention" do
      expect(reply_to("ну @test_bot режим: бухгалтер")).to be_nil
      expect(chat.reload).to be_default
    end

    it "ignores a longer username that starts with the bot's" do
      expect(reply_to("@test_botx режим: бухгалтер")).to be_nil
      expect(chat.reload).to be_default
    end

    it "ignores a bare mention" do
      expect(reply_to("@test_bot")).to be_nil
    end
  end

  describe "режим: ..." do
    def reply_to(text)
      described_class.new(user: user, chat: chat, text: text).call
    end

    it "switches mode and says so" do
      expect(reply_to("@test_bot режим: бухгалтер")).to eq("Активовано бухгалтерський режим.")
      expect(chat.reload).to be_accountant
    end

    it "says when the chat is already in that mode" do
      expect(reply_to("@test_bot режим: звичайний")).to eq("Я вже на звичайному режимі.")
      expect(chat.reload).to be_default
    end

    it "switches to quiet mode" do
      expect(reply_to("@test_bot режим: тихий")).to eq("Активовано тихий режим. Відповідаю лише на команди.")
      expect(chat.reload).to be_quiet
    end

    it "answers an unknown mode without switching" do
      expect(reply_to("@test_bot режим: вечірній")).to eq("Нема такого режиму.")
      expect(chat.reload).to be_default
    end
  end

  describe "камертон: ..." do
    def reply_to(text)
      described_class.new(user: user, chat: chat, text: text).call
    end

    it "turns Camerton on and off" do
      expect(reply_to("@test_bot камертон: увімкни")).to eq("Камертон увімкнено.")
      expect(chat.reload.camerton_enabled).to be(true)

      expect(reply_to("@test_bot камертон: вимкни")).to eq("Камертон вимкнено.")
      expect(chat.reload.camerton_enabled).to be(false)
    end

    it "says when Camerton is already in that state" do
      expect(reply_to("@test_bot камертон: вимкни")).to eq("Камертон вже вимкнений.")
    end

    it "asks again on an unknown argument without changing anything" do
      expect(reply_to("@test_bot камертон: може")).to eq("Камертон: увімкни або вимкни?")
      expect(chat.reload.camerton_enabled).to be(false)
    end

    it "works in every mode without changing the mode" do
      Chat.modes.each_key do |mode|
        chat.update!(mode: mode, camerton_enabled: false)

        expect(reply_to("@test_bot камертон: вкл")).to eq("Камертон увімкнено.")
        expect(chat.reload).to have_attributes(mode: mode, camerton_enabled: true)
      end
    end
  end

  describe "quiet mode" do
    it "answers no other commands" do
      chat.update!(mode: :quiet)

      expect(described_class.new(user: user, chat: chat, text: "@test_bot баланс").call).to be_nil
      expect(described_class.new(user: user, chat: chat, text: "@test_bot кава за тиждень").call).to be_nil
    end
  end

  describe "гатуни за an unknown period" do
    it "isn't a command" do
      expect(stats_for("вчора")).to be_nil
    end
  end

  describe "пошли @ / образь @" do
    def reply_to(text)
      described_class.new(user: user, chat: chat, text: text).call
    end

    before { user.update!(first_name: "Іван") }

    it "charges the author and mentions the target with a fuck-you phrase" do
      create(:user, username: "olga", chats: [ chat ])

      reply = reply_to("@test_bot пошли @olga")

      expect(reply).to start_with("Іван за 100 замовив: \n\n@olga ")
      expect(AnswerFiles.yaml("phrases", "fuck_you")).to include(reply.split("@olga ").last)
      expect(Point.sole).to have_attributes(user: user, chat: chat, amount: -100, reason: "пошли @olga")
    end

    it "uses the bigger fee and the swear list for образь" do
      create(:user, username: "olga", chats: [ chat ])

      expect(reply_to("@test_bot образь @olga")).to start_with("Іван за 150 замовив:")
      expect(Point.sole.amount).to eq(-150)
    end

    it "still charges when the target isn't in the chat" do
      expect(reply_to("@test_bot пошли @nobody")).to start_with("Такої людини тут нема, але 100")
      expect(Point.sole.amount).to eq(-100)
    end
  end

  def with_system_time_zone(zone)
    original = ENV["TZ"]
    ENV["TZ"] = zone
    yield
  ensure
    ENV["TZ"] = original
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
