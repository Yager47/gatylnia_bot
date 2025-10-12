class Response
  class Equals

    DATA = {
      "добре" => ["Ні, це не добре", "Ні, це погано"],
      "харашо" => ["Ні, це не харашо", "Ні, це погано"],
      "погано" => ["Ні, не погано", "Ні, це добре", "Ні, це ахуєнно"],
      ["ок", "оке", "окей"] => "Ні, не окей",
      "блять" => ["Блять треба дома оставлять", "Єбать"],
      "єбать" => "Блять",
      ["пізда", "пизда"] => "Хуй", "хуй" => "Пізда",
      "так" => "Ні", "так!" => "Ні!",
      "ні" => "Ні", "ні!" => "Так!",
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
      swear_phrases => swear_answers,
      # elsif swear_variants.include?(@text[3..-1])
      # send_to_chat ["Ти шо сука", "Ні, ти #{@text[3..-1]}"],
    }

    private_constant DATA

    def self.response(text)
      DATA.keys.each do |key|
        if key.is_a?(Array)
          key.each do |sub_key|
            return answer(key) if text == sub_key
          end
        else
          return answer(key) if text == key
        end
      end
    end

    private

    def swear_phrases
      fuck_you_phrases + phrases("swear")
    end

    def swear_answers
      res = ["Ти шо сука", "Ні, ти #{@text}"]
      res << "Я піду, а чи повернусь я?" if fuck_you_phrases.include?(@text)
      res
    end

    def fuck_you_phrases
      @fuck_you_phrases ||= phrases("fuck_you")
    end
  end
end