module Response
  class Base
    def initialize(user:, text:)
      @user = user
      @text = text
    end

    def response
      raise NotImplementedError
    end

    private

    def data
      raise NotImplementedError
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
      if locals.present?
        path = Rails.root.join("lib/#{type}/#{name}.yml.erb")
        erb_text = ERB.new(File.read(path)).result_with_hash(locals)

        YAML.safe_load erb_text
      else
        YAML.load_file Rails.root.join("lib/#{type}/#{name}.yml")
      end
    end
  end
end