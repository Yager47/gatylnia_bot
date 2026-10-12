# Loads the bot's phrase/answer files and prompts from lib/ once per process
# instead of on every message.
#
# Cached values are shared by every Puma and Solid Queue thread, so they're
# deep-frozen: a caller that mutated one would otherwise change it for every
# later message. With code reloading on (development) nothing is cached, so
# edits to the files show up without a restart.
module AnswerFiles
  CACHE = Concurrent::Map.new

  module_function

  # lib/<type>/<name>.yml, parsed.
  def yaml(type, name)
    fetch([ :yaml, type, name ]) { deep_freeze(YAML.load_file(path("lib/#{type}/#{name}.yml"))) }
  end

  # lib/<type>/<name>.yml.erb rendered with locals, then parsed. The output
  # differs per call, so only the compiled template is cached.
  def erb(type, name, locals)
    template = fetch([ :erb, type, name ]) { ERB.new(File.read(path("lib/#{type}/#{name}.yml.erb"))).freeze }
    YAML.safe_load(template.result_with_hash(locals))
  end

  # Raw text of a file under the app root, e.g. "lib/ai_prompt/v2.txt".
  def text(relative_path)
    fetch([ :text, relative_path ]) { File.read(path(relative_path)).freeze }
  end

  def clear
    CACHE.clear
  end

  # compute_if_absent runs the block at most once per key, even when several
  # threads ask for the same file at the same moment. It holds a lock while
  # the block runs, so the block must not call fetch (or yaml/erb/text)
  # itself: that deadlocks. Load what the block needs before calling fetch.
  def fetch(key, &load)
    return load.call if Rails.application.config.enable_reloading

    CACHE.compute_if_absent(key, &load)
  end

  def path(relative_path)
    Rails.root.join(relative_path)
  end

  def deep_freeze(value)
    case value
    when Hash then value.each { |key, item| deep_freeze(key) && deep_freeze(item) }
    when Array then value.each { |item| deep_freeze(item) }
    end
    value.freeze
  end
end
