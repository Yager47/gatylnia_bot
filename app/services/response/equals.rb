module Response
  class Equals < Response::Base
    def process
      # Talk back
      success talk_back_answer if swear_phrases.include?(@text[3..-1])

      data.keys.each do |key|
        if key.is_a?(Array)
          key.each do |sub_key|
            success answer(key) if @text == sub_key
          end
        else
          success answer(key) if @text == key
        end
      end
    end

    private

    def talk_back_answer
      ["Ти шо сука", "Ні, ти #{@text[3..-1]}"].sample
    end

    def swear_phrases
      fu_phrases + phrases("swear")
    end

    def swear_answers
      result = ["Ти шо сука", "Ні, ти #{@text}"]
      result << "Я піду, а чи повернусь я?" if fu_phrases.include?(@text)
      result
    end

    def fu_phrases
      @fu_phrases ||= phrases("fuck_you")
    end

    def data
      {
        "добре" => ["Ні, це не добре", "Ні, це погано"],
        "харашо" => ["Ні, це не харашо", "Ні, це погано"],
        "погано" => ["Ні, не погано", "Ні, це добре", "Ні, це ахуєнно"],
        ["ок", "оке", "окей"] => "Ні, не окей",
        "блять" => ["Блять треба дома оставлять", "Єбать"],
        "єбать" => "Блять",
        ["пізда", "пизда"] => "Хуй", "хуй" => "Пізда",
        "так" => "Ні", "так!" => "Ні!",
        "ні" => "Так", "ні!" => "Так!",
        "ало" => "Ало", "алло" => "Алло",
        "це пізда" => ["Ні, це хуй", "Ні, не пізда"],
        "нє" => "Хуй в говнє",
        ["реально", "скажи"] => "Внатурє",
        "це правда" => ["Ні, це брехня", "Ні, не правда"],
        "да" => "Пізда",
        "це піздєц" => "Погоджуюсь",
        "піздєц" => "Згоден",
        ["боже", "господи"] => answers("god"),
        "угу" => "Шо ти угукаєш, дура",
        "ага" => "Шо ти агакаєш, дура",
        ["шо", "шо?"] => "Хуй зʼїв нашо",
        "тю" => "Не на ту кутю",
        "йо" => "Йо!", "йоу" => "Йоу!",
        ["я", "я!", "і я", "я також"] => "Головка от хуя",
        ["та йди ти нахуй", "та йди нахуй"] => ["Їбало притуши", "Своїм помахуй"],
        ["розпач", "rozpach"] => answers("rozpach"),
        swear_phrases => swear_answers
      }
    end
  end
end