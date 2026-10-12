module Response
  class Base
    def initialize(user: nil, text: nil)
      @user = user
      @text = text
    end

    def process
      raise NotImplementedError
    end

    private

    def success(response)
      if response.blank?
        raise Skip
      else
        raise Success, response
      end
    end

    def answer(key)
      result = data[key]

      while result.is_a?(Array) do
        result = result.sample
      end

      result
    end

    def phrases(name, locals = {})
      get("phrases", name, locals)
    end

    def answers(name, locals = {})
      get("answers", name, locals)
    end

    def get(type, name, locals = {})
      locals.present? ? AnswerFiles.erb(type, name, locals) : AnswerFiles.yaml(type, name)
    end
  end
end