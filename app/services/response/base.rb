module Response
  class Base
    def initialize(user: nil, text: nil)
      @user = user
      @text = text
    end

    # Returns a reply String, Response::STOP or nil (see Response).
    def call
      raise NotImplementedError
    end

    private

    # An empty reply stops the chain without answering.
    def reply(text)
      text.presence || STOP
    end

    def answer(key)
      pick(data[key])
    end

    # Answers can be nested lists; pick one string at random.
    def pick(value)
      value = value.sample while value.is_a?(Array)
      value
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
