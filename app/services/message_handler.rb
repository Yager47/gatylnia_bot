class MessageHandler
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
      # elsif @message[:reply_to_message].present? && true
        # reply_to_message
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

      elsif @text.include?("ахах")
        send_to_chat laugh_response_text
      elsif @text.include?("f[f[")
        send_to_chat laugh_response_text
      elsif @text.include?("))")
        send_to_chat smile_response_text
      elsif @text.include?("((")
        send_to_chat sad_response_text
      elsif @text.include?("ааа")
        send_to_chat aaa_response_text
      elsif @text.include?("ооо")
        send_to_chat ooo_response_text
      elsif @text.include?("кав") && !@text.include?("цікав")
        send_to_chat coffee_response
      elsif @text.include?("текіл") || @text.include?("свєт")
        send_to_chat "Мальчікіііііііі"
      elsif @text.include?("пить") || @text.include?("пити") || @text.include?("бухат")
        send_to_chat "Шоб і не балакать"
      elsif @text.include?("заборони")
        send_to_chat "Забороняю!"
      elsif @text.include?("вічність")
        send_to_chat "Вічність тут"
      elsif @text.include?("не нада") || @text.include?("ненада")
        send_to_chat "Нада"
      elsif @text.include?("нада") || @text.include?("надо")
        send_to_chat "Ні, не нада"
      elsif @text.include?("не можу")
        send_to_chat "Ні, ти можеш"
      elsif @text.include?("можу")
        send_to_chat "Ні, не можеш"
      elsif @text.include?("не можна")
        send_to_chat "Можна"
      elsif @text.include?("не люблю")
        send_to_chat "Ні, ти любиш"
      elsif @text.include?("люблю")
        send_to_chat "Ні, не любиш"
      elsif @text.include?("можна")
        send_to_chat "Ні, не можна"
      elsif @text.include?("не треба")
        send_to_chat "Ні, треба"
      elsif @text.include?("треба")
        send_to_chat "Ні, не треба"
      elsif @text.include?("не будем")
        send_to_chat "Будете"
      elsif @text.include?("будем")
        send_to_chat "Ні, не будете"
      elsif @text.include?("не буду")
        send_to_chat "Ні, ти будеш"
      elsif @text.include?("не буде")
        send_to_chat "Ні, буде"
      elsif @text.include?("не будуть")
        send_to_chat "Ні, вони будуть"
      elsif @text.include?("буде")
        send_to_chat "Ні, не буде"
      elsif @text.include?("будуть")
        send_to_chat "Ні, не будуть"
      elsif @text.include?("буду")
        send_to_chat "Ні, не будеш"
      elsif @text.include?("хочу")
        send_to_chat "Ні, не хочеш"
      elsif @text.include?("не хочу")
        send_to_chat "Ні, ти хочеш"
      elsif @text == "добре"
        send_to_chat ["Ні, це не добре", "Ні, це погано"].sample
      elsif @text == "погано"
        send_to_chat ["Ні, не погано", "Ні, це добре", "Ні, це ахуєнно"].sample
      elsif @text.include?("один") && !@text.include?("годин")
        send_to_chat "Проти цілого світу?"
      elsif @text.include?("не знаю")
        send_to_chat "Ні, ти знаєш"
      elsif @text.include?("знаю")
        send_to_chat "Ні, ти не знаєш"
      elsif @text.include?("поняв")
        send_to_chat "Ні, ти не поняв"
      elsif @text.include?("смислі")
        send_to_chat "В коромислі"
      elsif @text.include?("смислє")
        send_to_chat "В коромислє"
      elsif @text.include?("бик") || @text.include?("бичар")
        send_to_chat ["Сам ти бик", "А ти корова", "Від бика чую", "ММУУУУУ"].sample
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
      elsif @text.include?("кайф")
        send_to_chat "Кайф лютий"
      elsif @text.include?("гандон")
        send_to_chat "Штопаний"
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
      elsif @text.include?("плачу")
        send_to_chat ["Не плач", "Плакса", "Нюня"].sample
      elsif @text.include?("рево")
        send_to_chat ["Рево це ахуєнно", "Захотілось баночку рево", "Поїхали на заправку рево пить"].sample
      elsif @text.include?("важко") || @text.include?("тяжко")
        send_to_chat "А кому легко"
      elsif @text.include?("чуєш")
        send_to_chat "На хую переночуєш"
      elsif @text.include?("прекрасно")
        send_to_chat "Ні, це жахливо"
      elsif @text.include?("жах")
        send_to_chat ["Ні, це прекрасно", "Ні, це ахуєнно"].sample
      elsif @text.include?("не вірно") || @text.include?("невірно")
        send_to_chat "Ні, це вірно"
      elsif @text.include?("вірно")
        send_to_chat ["Ні, це хибно", "Ні, це помилка", "Ні, це невірно"].sample
      elsif @text.include?("не правильно") || @text.include?("неправильно")
        send_to_chat "Ні, це правильно"
      elsif @text.include?("правильно")
        send_to_chat ["Ні, це хибно", "Ні, це помилка", "Ні, це неправильно"].sample
      elsif @text.include?("алкоголь це яд")
        send_to_chat "Отрута це гурт"
      elsif @text.include?("алкоголь")
        send_to_chat "Алкоголь це яд"
      elsif @text.include?("отрута")
        send_to_chat "Отрута це гурт"
      elsif @text.include?("в аху") || @text.include?("ваху")
        send_to_chat "Ні, ти не в ахуі"
      elsif @text.include?("боря друг")
        send_to_chat "Боря брат"
      elsif @text.include?("саша друг")
        send_to_chat "Саша брат"
      elsif @text.include?("саня друг")
        send_to_chat "Саня брат"
      elsif @text.include?("сєрий друг")
        send_to_chat "Сєрий брат"
      elsif @text.include?("данік друг")
        send_to_chat "Данік брат"
      elsif @text.include?("даня друг")
        send_to_chat "Даня брат"
      elsif @text.include?("мормуль друг")
        send_to_chat "Мормуль брат"
      elsif @text.include?("боря")
        send_to_chat ["БОРЯЯЯЯЯ!!", "Боря блять"].sample
      elsif @text.include?("сєрий")
        send_to_chat "СЄРЬОЖАААА!!"
      elsif @text.include?("саша")
        send_to_chat "САШАААААА!!"
      elsif @text.include?("саня")
        send_to_chat "САНЯЯЯЯЯЯ!!"
      elsif @text.include?("мормуль")
        send_to_chat "МОРМУУУУЛЬ!!"
      elsif @text.include?("данік")
        send_to_chat "ДАНІІІК!!"
      elsif @text.include?("даня")
        send_to_chat "ДАНЯЯЯЯЯЯ!!"
      elsif @text.include?("мінімум")
        send_to_chat "Більше можна \nМенше нізя"
      elsif @text.include?("максимум")
        send_to_chat "Менше можна \nБільше нізя"
      elsif @text.include?("більше можна") || @text.include?("можна більше")
        send_to_chat "Менше нізя"
      elsif @text.include?("менше можна") || @text.include?("можна менше")
        send_to_chat "Більше нізя"
      elsif @text.include?("не сподобалось")
        send_to_chat "Ні, сподобалось"
      elsif @text.include?("сподобалось")
        send_to_chat "Ні, не сподобалось"
      elsif @text.include?("послухав")
        send_to_chat "Ні, не послухав"
      elsif @text.include?("сдєлав?")
        send_to_chat "Проєбав"
      elsif @text.include?("джент корпорейшн")
        send_to_chat djent_corp_response
      elsif @text.include?("підар")
        send_to_chat "Підари кругом"
      elsif @text.include?("чіна")
        send_to_chat ["Саунтрес", "Урде сурде", "Санчізес", "Урдосанчізес", "Чінаурде урде"].sample
      elsif @text.include?("кріпт")
        send_to_chat ["Кріпта тєма дурна", "Кріпта це ахуєнно", "Обережно! Пересуваєця кріптовалютчик"].sample
      elsif @text == "йо"
        send_to_chat "Йо!"
      elsif @text == "йоу"
        send_to_chat "Йоу!"
      elsif @text.include?("свій оазис")
        send_to_chat "Не знайти, а створити"
      elsif @text.include?("оазис")
        send_to_chat "Його не знайти"
      elsif @text.include?("вибач")
        send_to_chat ["Та нічо", "Бог простить", "У Бога проси пробачення", "Не вибачу", "Вибачаю"].sample
      elsif @text.include?("не ригай хуйню")
        send_to_chat ["Я должен", "Я буду", "Я не можу"].sample
      elsif @text.include?("заткнись")
        send_to_chat ["Я не можу", "Ні, буду пиздіть", "Ні, не заткнусь"].sample
      elsif @text.include?("закрий") || @text.include?("стули") || @text.include?("завали")
        send_to_chat ["Я не можу", "Ні, буду пиздіть"].sample
      elsif @text.include?("живий")
        send_to_chat "Назавжди живий"
      elsif @text.include?("горить")
        send_to_chat "Поглянь як горить"
      elsif @text.include?("сюда") || @text.include?("суда")
        send_to_chat "На базу"
      elsif @text.include?("за шо") || @text.include?("зашо")
        send_to_chat "За все хароше"
      elsif @text.include?("шляпа") && !@text.include?("рисова")
        send_to_chat "Рисова"
      elsif @text.include?("шляпи") && !@text.include?("рисові")
        send_to_chat "Рисові"
      elsif @text.include?("шляпа рисова")
        send_to_chat ["Шляпа з рису, получається", "Їв таку шляпу, не смачна"].sample
      elsif @text.include?("не смішно")
        send_to_chat "Ні, це смішно"
      elsif @text.include?("смішно")
        send_to_chat "Ні, це не смішно"
      elsif ["я", "я!", "і я", "я також"].include?(@text)
        send_to_chat "Головка от хуя"
      elsif @text.include?("аменр")
        send_to_chat "Ти заєбав зі своєю Аменрою"
      elsif ["та йди ти нахуй", "та йди нахуй"].include?(@text)
        send_to_chat ["Їбало притуши", "Своїм помахуй"].sample
      elsif ["розпач", "rozpach"].include?(@text)
        send_to_chat ["РООЗПААЧЧ!", "Чув їх, таку хуйню грають", "ROZPACH це ахуєнно", "Маткор лютий", "Гнів"].sample
      elsif @text.include?("гнів") || @text.include?("відчай")
        send_to_chat "Розпач"
      elsif @text.include?("ненавиджу")
        send_to_chat "Я не навиджу тебе \nТи ненавидиш мене"
      elsif @text.include?("кожний день")
        send_to_chat "Кожна хвилина"
      elsif @text.include?("кожна хвилина")
        send_to_chat "Кожна секунда"
      elsif @text.include?("кожна секунда")
        send_to_chat "Кожна година"
      elsif @text.include?("кожна година")
        send_to_chat "Кожний місяць"
      elsif @text.include?("кожний місяць")
        send_to_chat "Кожний рік"
      elsif @text.include?("кожний рік")
        send_to_chat "Мають значення для нас всіх"
      elsif @text.include?("мають значення")
        send_to_chat "Для нас всіх"
      elsif @text.include?("лишився лише")
        send_to_chat "РОЗПАЧ!"
      elsif @text.include?("в моїй душі")
        send_to_chat "РООООЗПААААААААЧ!!!!"
      elsif @text.include?("кожн") || @text.include?("кожен")
        send_to_chat "Кожний день"
      elsif @text.include?("кожна")
        send_to_chat "Кожна хвилина"
      elsif @text.include?(" рай") || @text.include?(" раю")
        send_to_chat "Тісний рай, получається"
      elsif @text.include?("виставка дисторшн")
        send_to_chat "Виставка Поноса"
      elsif @text.include?("виставку дисторшн")
        send_to_chat "Виставку Поноса"
      elsif @text.include?("виставк")
        send_to_chat "Дисторшн"
      elsif swear_variants.include?(@text)
        send_to_chat swear_response
      elsif swear_variants.include?(@text[3..-1])
        send_to_chat ["Ти шо сука", "Ні, ти #{@text[3..-1]}"].sample
      elsif thank_condition?
        send_to_chat thank_response
      elsif morning_condition?
        send_to_chat morning_response
      elsif @text.include?("добраніч")
        send_to_chat ["Добраніч, #{@user.first_name}, тіряйся брат", "Солодких снів, пан #{@user.first_name}"].sample
      elsif @text.include?("?")
        send_to_chat question_response_text
      elsif @text.include?("!")
        send_to_chat exclamation_response_text
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
      "йди нахуй", "іди нахуй", "іди в пизду","йдинахуй", "ідинахуй", "пішов нахуй"
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
      ")", ")0", "))", "))0", ")))", ")))))", "))))))))))", ")))))))))))))))))",
      ")))))))))))))000000"
    ].sample
  end

  def sad_response_text
    [
      "(", "((", "(((", "(((((", "((((((((((", "(((((((((((", "(((((((((((((((((((",
      "Не сумуй"
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
