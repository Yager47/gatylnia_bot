class MessageHandlerNew
  BOT_NAME = "@GatylniaBot"

  def initialize(message)
    @bot = Telegram::Bot::Client.new(ENV.fetch("TELEGRAM_BOT_API_TOKEN"))
    @message = message
    @chat = process_chat
    @user = process_user

    @text = nil
  end

  def call
    return unless @message
    return unless @message[:date]

    # Skip if message was edited later than minute after the original one.
    # Telegram re-sends video messages as edited message after some time for unknown reason.
    return if @message[:edit_date].present? && (Time.now > Time.at(@message[:date]) + 1.minute)

    if @message[:text]
      @text = @message[:text].downcase

      if entry_variants.include?(@text)
        @user.entries.create!(
          chat: @chat,
          message: @message[:text]
        )
        send_to_chat response_text
      elsif @text == "видали гатіння"
        @user.entries.last&.destroy
        send_to_chat "Твоє останнє гатіння видалено. \nТіряйся"
      elsif @text == "#{BOT_NAME.downcase} підтримай мене"
        send_to_chat support_response
      elsif @text == "#{BOT_NAME.downcase} дай ритм"
        send_to_chat rhythm
      elsif @text == "#{BOT_NAME.downcase} пошли когось" && @chat.users.present?
        send_to_chat "@#{@chat.users.sample.username} #{fu_variants.sample}"
      elsif @text == "#{BOT_NAME.downcase} пошли мене"
        send_to_chat "@#{@user.username} #{fu_variants.sample}"
      elsif @text == "#{BOT_NAME.downcase} образь когось" && @chat.users.present?
        send_to_chat "@#{@chat.users.sample.username} #{swear_variants.sample}"
      elsif @text == "#{BOT_NAME.downcase} образь мене"
        send_to_chat "@#{@user.username} #{swear_variants.sample}"
      elsif @text.include?("#{BOT_NAME.downcase} гатуни за ")
        call_bot_command
      elsif @text.include?("не гат") || @text.include?("не погат")
        send_to_chat ["Нічого, все буде!", "Тримайся!", "У тебе все ВИЙДЕ! \nАхахахах", "Я вірю в тебе!"].sample
      elsif @text.include?("гат")
        send_to_chat(
          "Якшо ти гатиш, напиши нормально, одним словом: гатю, погатив, сру, насрав, посрав, какаю і т.д.\n\n" \
          "Якшо ти хочеш, шоб я видалив твоє останнє гатіння, напиши: \"видали гатіння\""
        )
      elsif @text.include?("в рот") || @text.include?("врот")
        send_to_chat mouth_response_text
      elsif @message[:text].include?(BOT_NAME)
        send_to_chat bot_call_response




      elsif @text == "добре"
        send_to_chat ["Ні, це не добре", "Ні, це погано"].sample
      elsif @text == "погано"
        send_to_chat ["Ні, не погано", "Ні, це добре", "Ні, це ахуєнно"].sample
      elsif @text == "блять"
        send_to_chat ["Блять треба дома оставлять", "Єбать"].sample
      elsif @text == "єбать"
        send_to_chat "Блять"
      elsif @text == "пізда" || @text == "пизда"
        send_to_chat "Хуй"
      elsif @text == "хуй"
        send_to_chat "Пізда"
      elsif @text == "так" || @text.include?("так!")
        send_to_chat "Ні"
      elsif @text == "ні" || @text.include?("ні!")
        send_to_chat "Так"
      elsif @text == "ало"
        send_to_chat "Ало"
      elsif @text == "алло"
        send_to_chat "Алло"
      elsif @text == "це пізда"
        send_to_chat ["Ні, це хуй", "Ні, не пізда"].sample
      elsif @text == "реально"
        send_to_chat "Внатурє"
      elsif @text == "це правда"
        send_to_chat ["Ні, це брехня", "Ні, не правда"].sample
      elsif @text == "скажи"
        send_to_chat "Внатурє"
      elsif @text == "да"
        send_to_chat "Пізда"
      elsif @text == "це піздєц"
        send_to_chat "Погоджуюсь"
      elsif @text == "піздєц"
        send_to_chat "Згоден"
      elsif @text == "боже" || @text == "господи"
        send_to_chat ["Боже правий", "Господи боже", "Господи прости", "Іісусе", "Ради Христа", "Свята Дєва Марія", "Свята Дєва Марія і Іосіф"].sample
      elsif @text == "угу"
        send_to_chat "Шо ти угукаєш, дура"
      elsif @text == "ага"
        send_to_chat "Шо ти агакаєш, дура"
      elsif @text == "шо" || @text == "шо?"
        send_to_chat "Хуй зʼїв нашо"
      elsif @text == "тю"
        send_to_chat "Не на ту кутю"
      elsif @text == "йо"
        send_to_chat "Йо!"
      elsif @text == "йоу"
        send_to_chat "Йоу!"
      elsif ["я", "я!", "і я", "я також"].include?(@text)
        send_to_chat "Головка от хуя"
      elsif ["та йди ти нахуй", "та йди нахуй"].include?(@text)
        send_to_chat ["Їбало притуши", "Своїм помахуй"].sample
      elsif ["розпач", "rozpach"].include?(@text)
        send_to_chat ["РООЗПААЧЧ!", "Чув їх, таку хуйню грають", "ROZPACH це ахуєнно", "Маткор лютий", "Гнів"].sample
      elsif swear_variants.include?(@text)
        send_to_chat swear_response
      elsif swear_variants.include?(@text[3..-1])
        send_to_chat ["Ти шо сука", "Ні, ти #{@text[3..-1]}"].sample
      elsif thank_condition?
        send_to_chat thank_response
      elsif morning_condition?
        send_to_chat morning_response
      elsif chance(1, 5)
        send_to_chat chance_responses.sample(10).sample
      end

    elsif @message[:video_note]
      duration = @message.dig(:video_note, :duration)

      if duration > 27
        send_to_chat push_up_video_response
      else
        if Time.now > "18:30".to_time || Time.now < "04:00".to_time
          send_to_chat evening_short_video_response
        else
          send_to_chat coffee_video_response
        end
      end

    elsif @message[:voice]
      send_to_chat ["А текстом нізя було?", "Не души голосовухами, я тебе просю"].sample
    elsif @message[:forward_from] || @message[:forward_from_chat]
      send_to_chat ["Нахуй ти сюди це переслав?", "Пересилай назад", "Ні, ти не переслав"].sample
    else
      send_to_chat(chance_responses.sample(10).sample) if chance(1, 5)
    end
  end

  private

  def process_chat
    Chat.find_by(telegram_id: @message[:chat][:id]) ||
      begin
        Chat.create!(
          telegram_id: @message[:chat][:id],
          telegram_type: @message[:chat][:type],
          title: @message[:chat][:title]
        )
      end
  end

  def process_user
    User.find_by(telegram_id: @message[:from][:id]) ||
      begin
        User.create!(
          chat: @chat,
          telegram_id: @message[:from][:id],
          username: @message[:from][:username],
          first_name: @message[:from][:first_name],
          last_name: @message[:from][:last_name]
        )
      end
  end

  def send_to_chat(text)
    @bot.api.send_message(chat_id: @chat.telegram_id, text: text)
  end

  def call_bot_command
    command = @text.sub("#{BOT_NAME.downcase} гатуни за ", "").downcase

    BotCommand.new(bot: @bot, chat: @chat, command: command).call
  end

  def coffee_response
    coffee_variants.sample
  end

  def coffee_video_response
    (universal_video_variants + coffee_variants).sample
  end

  def evening_short_video_response
    (universal_video_variants + [
      "Ставлю жопу, шо пʼєш мразь", "Бухаєш вже?", "Ох ти ж і мразота", "Гнида",
      "Добрий вечір", "А ми вже відпочиваєм, бачу", "Алкоголь ллється рікою?"
    ]).sample
  end

  def push_up_video_response
    (universal_video_variants + [
      "Ну ти машина вже піздєц", "Покажи банку", "Ох і машина", "Страшний", "Страшний піздєц",
      "Машина"
    ]).sample
  end

  def coffee_variants
    [
      "Скіки можна ту каву пить", "Каводрочер", "Кава це ахуєнно", "Виявлено кавохльоба",
      "А працювать коли?", "Кавуся сьорб-сьорб?", "Їбуняча кава напевно"
    ]
  end

  def universal_video_variants
    [
      "Ох і красіва дура", "Яка машина", "Камеру протри", "А красівий який",
      "Гарний", "А гарний, так і дав би в рот", "А гарний який, дав би в ротяку"
    ]
  end

  def entry_variants
    [
      "гатю", "погатив", "по гатив", "гатонув", "гатив", "нагатив", "відгатив",
      "гатонув", "гатанув", "сру", "посрав", "по срав", "насрав", "срав",
      "навалив", "какаю", "покакав", "какав", "накакав", "дріщу", "дрістаю",
      "дристаю", "дрищу"
    ]
  end

  def fu_variants
    [
      "йди нахуй", "іди нахуй", "іди в пизду", "йдинахуй", "ідинахуй", "пішов нахуй"
    ]
  end

  def swear_variants
    fu_variants + [
      "мразь", "ахуєл", "підар", "гандон", "мразота", "тварь", "тварь кончена",
      "дибіл", "йобнутий", "єбанутий", "придурок", "гнида", "ідіот", "тіряйся",
      "дура", "тіряйся дура", "довбойоб", "долбойоб", "дурак", "тварина",
      "кончений", "урод"
    ]
  end

  def thank_condition?
    @text.include?("дякую") || @text.include?("дяка") ||@text.include?("подякував") ||
      @text.include?("пасіб") ||@text.include?("пасиб")
  end

  def thank_response
    [
      "Будеш должен", "Ні, ти не дякуєш", "Богу дякуй", "На здоровʼя", "Дивись не подавись",
      "Аби тобі подобалось", "Є за шо"
    ].sample
  end

  def response_text
    respond_variants.sample
  end

  def support_response
    support = ["все буде добре", "тримайся", "у тебе все вийде", "я вірю в тебе", "ти найкращий"].sample
    "#{@user.first_name}, #{support}!"
  end

  def bot_call_response
    recall = @message[:text].sub(BOT_NAME, "@#{@user.username}")
    recall2 = "Додік @#{@user.username} написав: \"#{@message[:text].sub(BOT_NAME + ' ', '')}\""

    resp = [
      "Шо", "Шо ти хочеш", "Шо нада", "Не дьоргай мене", "Отстань", "Да-да?",
      "Ну шоооо", "...", "Не трогай мене", "Шо тобі нада", "Шо тобі треба",
      "Не тошни", "Шо", "Ну шо?", "Ну шо", "Шо?!", "Шо?", "Мальчікііііі",
      "Потіряйся", "Потіряйся прошу", "Йдинахуй", "Іди нахуй", "Я занятий",
      "Тобі нема кого трогать?", "Відчепись", "Не чує баба", "Ще раз"
    ].sample

    [resp, resp, resp, recall, recall2].sample
  end

  def swear_response
    resp = ["Ти шо сука", "Ні, ти #{@text}"]
    resp << "Я піду, а чи повернусь я?" if fu_variants.include?(@text)
    resp.sample
  end

  def morning_condition?
    @text.include?("доброго ранку") || @text.include?("добрий ранок") ||
      @text.include?("ранок добрий") || @text.include?("добрий раночок") ||
      @text.include?("раночку")
  end

  def morning_response
    [
      "Доброго ранку, брат #{@user.first_name}!",
      "Раночку, пан #{@user.first_name}",
      "Добрий ранок! #{@user.first_name}, готовий нагатити сьогодні?"
    ].sample
  end

  def laugh_response_text
    [laugh_respond_variants_1.sample, laugh_respond_variants_2.sample].sample
  end

  def smile_response_text
    [
      ")", ")0", "))", "))0", ")))", ")))))", "))))))))))", ")))))))))))))))))", ")))))))))))))000000"
    ].sample
  end

  def sad_response_text
    [
      "(", "((", "(((", "(((((", "((((((((((", "(((((((((((", "(((((((((((((((((((", "Не сумуй"
    ].sample
  end

  def aaa_response_text
    [
      "аааааааа", "АААААААААА", "аааааааааааа", "ААААААААААААААААААА", "АААааААааААААаааАА",
      "аааААААААААаааа", "АААААААААААААА", "ааааааааааааааааааа", "ААААаааааааааа", "БЕЕЕЕЕ"
    ].sample
  end

  def ooo_response_text
    [
      "оооооооо", "ОООООООООО", "оооооооооооо", "ООООООООООООООООООО", "ОООооООооООООоооОО",
      "оооООООООООоооо", "ОООООООООООООО", "ооооооооооооооооооо", "ООООоооооооооо"
    ].sample
  end

  def mouth_response_text
    mouth_respond_variants.sample
  end

  def question_response_text
    question_respond_variants.sample
  end

  def exclamation_response_text
    exclamation_respond_variants.sample
  end

  def djent_corp_response
    slogan = [
      "і в рот візьмемо, і по їбалу дамо",
      "і плитку положем, і труби переріжем",
      "трубку не берем, в рот - берем",
      "в рот берем, трубку - не берем",
      "спочатку робим, потім - перероблюєм",
      "в рот дав - в рот взяв",
      "ми вам гроші, ви нам - в рот",
      "приймаєм заявки тіки на DJuice",
      "до Пасхи зробим",
      "не пишіть, ми не приїдем",
      "пишіть, дзвоніть - ми не приїдем"
    ].sample

    "Джент Корпорейшн: #{slogan}"
  end

  def respond_variants
    [
      "Ні, не #{@text}",
      "+200",
      "Набереш. \nНа старий, бажано.",
      "Набереш.",
      "Бля, ну гато-маткор лютий! Мінімум #{rhythm}",
      "#{@user.first_name}, ти остання надія маткору! Прибор показує ритм гатіння: #{rhythm}",
      "Маткорно гатиш, синку! Ритм смутку: #{rhythm}",
      "Зафіксовано маткорне гатіння: #{rhythm}",
      "Ох і вонюче, напевно. Ну скажи чесно, #{@user.first_name}, вонюче?",
      "Всім колективом \"#{@chat.title}\" щиро вітаємо тебе з цим, #{@user.first_name}!",
      "Ох жеш і дура красіва! Гатіння не закінчиться ніколи!",
      "Наставте вогників цьому пану шептуну! #{@user.first_name}, VIVA LA GATO!",
      "Ох ти і маткорщик-гатун, я хуєю. Красава, #{@user.first_name}.",
      "Ох і пахуча мачмалига там, напевно. Вітаю, #{@user.first_name}!",
      "Тримай в курсі, #{@user.first_name}.",
      "УВАГА! #{@user.first_name} гатить як чорт!",
      "Харош! Жопка може коли хоче! Ми всі пишаємось тобою, #{@user.first_name}!",
      "ГАТ! ГАТ! ГАТ! Так тримати, #{@user.first_name}!",
      "Зустрічайте! #{@user.first_name} \"Гатильна Машина\" #{@user.last_name}!",
      "Добрий день, студія! #{@user.first_name} гатонув як в останнє!",
      "А ми подумали, шо то ядєрка вже єбанула! Не лякай так, #{@user.first_name}!",
      "Кайф! Пишаємось, #{@user.first_name}! Дзвони мамі!",
      "Гатить - твоє призначення! Не зупиняйся, #{@user.first_name}!",
      "Єбать! Глянь на свій туз, #{@user.first_name}, його не спасти брат, міняй.",
      "Я хуєю, клас! Гарнюня, #{@user.first_name}!",
      "І це прекрасно! Щаслива ти людина, #{@user.first_name}!",
      "GATTUSO!!! Є гол, є перемога!! Вітаю, #{@user.first_name}!",
      "GATTUSOOOO!!! ГООООООЛЛЛЛ!!!!",
      "Gattuso забиває мʼяч!",
      "Gattuso виборює гол своїй команді!! Неперевершено, #{@user.first_name}!",
      "Скажем цій какашці: тіряйся, дура!",
      "А чого так скромно, \"#{@text}\"? Дріщеш як тіки можеш, #{@user.first_name}!",
      "Гищ, гищ! Калові торпєди пиздують! #{@user.first_name}, кращий, брат.",
      "Ну ти і Влад Гатило! Гатіння зараховано, #{@user.first_name}.",
      "Чую, гатіння смутку було, не менше! Тримайся, #{@user.first_name}."
    ]
  end

  def rhythm
    "#{[3,5,6,7,9,10,11,13,14,15].sample}/#{[4,8,16].sample}"
  end

  def laugh_respond_variants_1
    [
      "ахахахахахахах", "ахахахахаахахахах", "ахахахахаха", "АХАХАХАХАХАХ", "ахахахахахахахах",
      "ахахах", "АХхахаХахАХахАХа", "АХАХАХАХАХАХАХАХА"
    ]
  end

  def laugh_respond_variants_2
    [
      "Дуже смішно.", "Смішно тобі?", "Посмійся мені тут", "Я шось смішне по-твоєму сказав?",
      "Не смійся", "Смішно я єбу", "Ха-ха", "...", "........", "Розйоб, скажи", ")", "))", "))))))",
      ")))))))))))", "Ні, це не смішно", "Ні, не Ахахахахах", "Ні, ти не посмівся", "Ні, ти поплакав",
      "Це ніхуя не смішно, пацани", "Істєріка", "Ржака", "Кєк", "Лол", "Смішно", "Харе ржать"
    ]
  end

  def question_respond_variants
    [
      "Не питай", "Не знаю", "Відповіді нема", "Ніхто не знає", "Це нікому не цікаво",
      "Ти не дізнаєшся ніколи", "А нашо воно тобі?", "А нашо воно тобі треба?", "Та шо ти пристав",
      "Нашо тобі це знать?", "Ти завязуй з такими питаннями", "А хуй його знає", "І да і нє",
      "Таке не питають в прілічних чатах", "Не задавай ідіотських питань", "Спитай когось розумнішого",
      "Ну сам подумай", "Боже", "Господи", "Господи боже", "А я єбу?", "А я єбу, я бот", "Відчепись",
      "Знав би - не сказав", "Хз", "Хуй зна", "Так", "Ні", "А ти як думаєш?", "Єбу", "Отстань",
      "Тебе це єбать не должно", "А тебе їбе?", "Ти послєдній кого це должно єбать"
    ]
  end

  def exclamation_respond_variants
    [
      "Не ори", "Чо ти ореш", "Заткнись", "Боже", "Господи", "Господи боже",
      "Не кричи", "Чччшшш", "Чшш, тихіше", "Та шо ти так ореш", "Закрий рот"
    ]
  end

  def mouth_respond_variants
    [
      "В рот я би дав", "Комусь в рот треба дать?", "Гиль-гиль сука, в ротяку",
      "Люблю коли беруть в рот", "Я б також в рот дав", "Хуйеприйомником запахло",
      "Всім дать в рот!", "Дам в рот!", "Люблю давать в рот", "Гиль-гиль", "Гиль-гиль сука",
      "Чвяк-чвяк", "[звуки сосанія]", "В ротердам ніхто не хоче?"
    ]
  end

  def chance(number, out_of)
    array_of_chances = Array.new(number, true) + Array.new(out_of - number, false)
    array_of_chances.sample
  end

  def chance_responses
    [
      "Ой, смереко...", "Ой, смереко, на краю села хатина", "Шож поробиш", "Стули писок", "Наркотіки є у когось?",
      "Ну шо ж ти зробиш", "Та отож", "...", "........", "Всім дуже цікаво", "Думаєш?", "Я тєбя прашу, не ригай хуйню",
      "Мда", "Ясно", "Понятно", "Набереш", "Набереш, на старий", "Як ви мене заїбали...", "Не ригай хуйню",
      "Як ви мені вже остопизділи", "Дав би в рот кожному", "Якийсь гейський чат", "Піздєц",
      "Погатить ніхто не хоче?", "АЙ ТЕЙК МАЙ СОООУУУЛЛЛ!!", "Ви часом не з Джент Корпорейшн?",
      "Шось ви розпизділись тут", "А працювати сьогодні хтось буде?", "Іди працюй", "Я хуєю",
      "УУУУААА-А-А-А", "Харе пиздіть", "Шо я тут забув", "В ротяку ніхто не хоче?", "Треба 'Тісний рай' записать",
      "За щоку сьогодні всі вже взяли?", "Бачу невиєбаний рот", "Сюда", "Суда", "Реально", "Нашо мене народили",
      "Суда \nНа базу", "Дам в рот", "Люблю вас, пацани", "Господи", "Боже", "Закрий їбало", "В ротердам ніхто не хоче?",
      "Господи боже", "З маткором не созванювались?", "Пацани, як вам ритм #{rhythm}?", "Які ж ви ідіоти",
      "Пацани, тіряйтесь в ритмі #{rhythm}", "Як ви мені вже втошнились тут", "Треба гатить, пацани",
      "Хочу дісонанс в #{rhythm}", "Ти щітаєш?", "Щас би простітуток", "Поїхали по шлюхам", "Поїхали на заправку рево пить",
      "Щас би простітуток, бажано мертвих", "Щас би кокаіна вʼєбать", "Щас би рево", "Хочу текіли",
      "Щас би рево, бажано на заправкє", "Пацани, ідіть нахуй", "Впизділись вже", "Боря блять",
      "У вас є пісня в #{rhythm}?", "Хочу трек в #{rhythm}", "Заткнись", "Хочу пива", "Треба текіли вʼєбать",
      "За шо мені це все?", "За шо мені ці страждання?", "Я ригаю", "Закрий рот", "ЙДИ НААААХУЙ",
      "Чуєш, а ти не зламаний ціпок случайно?", "Вонять треба не тут, а в параші своїй", "Маткорний спас скоро?",
      "Дам в рот кожному, в алфавітному порядку", "Тіряйтесь, в алфавітному порядку", "Тіряйтесь вже, дури"
    ]
  end
end
