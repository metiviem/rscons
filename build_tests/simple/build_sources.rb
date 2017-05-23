class MyProgram < Rscons::Builder
  def run(options)
    target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
    objects = env.build_sources(sources, [".o"], cache, vars)
    command = %W[gcc -o #{target}] + objects
    return false unless env.execute("#{name} #{target}", command)
    target
  end
end

Rscons::Environment.new do |env|
  env.add_builder(MyProgram.new)
  env.MyProgram("simple.exe", "simple.c")
end
