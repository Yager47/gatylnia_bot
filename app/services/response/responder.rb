module Response
  # Helpers shared by responders. Each responder defines its own initialize
  # and a #call that returns a reply String, Response::STOP or nil (see
  # Response).
  module Responder
    private

    # An empty reply stops the chain without answering.
    def reply(text)
      text.presence || STOP
    end

    # Answers can be nested lists; pick one string at random.
    def pick(value)
      value = value.sample while value.is_a?(Array)
      value
    end

    # lib/phrases/<name>.yml
    def phrases(name)
      AnswerFiles.yaml("phrases", name)
    end

    # lib/answers/<name>.yml
    def answers(name)
      AnswerFiles.yaml("answers", name)
    end

    # lib/answers/<name>.yml.erb, rendered with locals.
    def render_answers(name, **locals)
      AnswerFiles.erb("answers", name, locals)
    end

    # The reply a lib/rules/*.yml rule asks for (see the comments there).
    # `locals` are only used by a rule that renders an ERB answer file.
    def reply_with_rule(rule, **locals)
      return STOP if rule["stop"]
      return reply(pick(answers(rule["answers"]))) if rule["answers"]
      return reply(pick(render_answers(rule["render"], **locals))) if rule["render"]

      reply(pick(rule["reply"]))
    end

    def fu_phrases
      phrases("fuck_you")
    end

    def swear_phrases
      fu_phrases + phrases("swear")
    end
  end
end
