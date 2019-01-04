class StrictBuilder < Rscons::Builder
  def run(options)
    target, sources, cache, env = options.values_at(:target, :sources, :cache, :env)
    command = %W[gcc -o #{target}] + sources.sort
    if cache.up_to_date?(target, command, sources, env, strict_deps: true)
      target
    else
      ThreadedCommand.new(command, short_description: "#{name} #{target}")
    end
  end

  def finalize(options)
    standard_finalize(options)
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
