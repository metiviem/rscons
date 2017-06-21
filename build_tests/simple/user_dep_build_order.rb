class TestBuilder < Rscons::Builder
  def run(options)
    target, env, vars, cache = options.values_at(:target, :env, :vars, :cache)
    if target == "two"
      return false unless File.exists?("one")
    end
    wait_time = env.expand_varref("${wait_time}", vars)
    command = ["ruby", "-e", "require 'fileutils'; sleep #{wait_time}; FileUtils.touch('#{target}');"]
    standard_threaded_build("TestBuilder", target, command, [], env, cache)
  end

  def finalize(options)
    standard_finalize(options)
  end
end

Rscons::Environment.new do |env|
  env.add_builder(TestBuilder.new)
  env.TestBuilder("one", [], "wait_time" => "3")
  env.TestBuilder("two", [], "wait_time" => "0")
  env.depends("two", "one")
end
