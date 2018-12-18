class Fail < Rscons::Builder
  def run(options)
    target, cache, env, vars = options.values_at(:target, :cache, :env, :vars)
    wait_time = env.expand_varref("${wait_time}", vars)
    ruby_command = %[sleep #{wait_time}; exit 2]
    command = %W[ruby -e #{ruby_command}]
    standard_threaded_build("Fail #{target}", target, command, [], env, cache)
  end
  def finalize(options)
    standard_finalize(options)
  end
end

build do
  Rscons::Environment.new do |env|
    env.add_builder(Fail.new)
    4.times do |i|
      wait_time = i + 1
      env.Fail("foo_#{wait_time}", [], "wait_time" => wait_time.to_s)
    end
  end
end
