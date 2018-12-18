class StrictBuilder < Rscons::Builder
  def run(options)
    target, sources, cache, env = options.values_at(:target, :sources, :cache, :env)
    command = %W[gcc -o #{target}] + sources.sort
    unless cache.up_to_date?(target, command, sources, env, strict_deps: true)
      return false unless env.execute("StrictBuilder #{target}", command)
      cache.register_build(target, command, sources, env)
    end
    target
  end
end

build do
  Environment.new(echo: :command) do |env|
    env.add_builder(StrictBuilder.new)
    env.Object("one.o", "one.c", "CCFLAGS" => %w[-DONE])
    env.Object("two.o", "two.c")
    sources = File.read("sources", mode: "rb").split(" ")
    env.StrictBuilder("program.exe", sources)
  end
end
