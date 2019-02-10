class DebugBuilder < Rscons::Builder
  def run(options)
    target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
    command = %W[gcc -c -o #{target} #{sources.first}]
    if Rscons.vars["command_change"]
      command += %w[-Wall]
    end
    if Rscons.vars["new_dep"]
      sources += ["extra"]
    end
    if Rscons.vars["strict_deps1"]
      sources += ["extra"]
      strict_deps = true
    end
    if Rscons.vars["strict_deps2"]
      sources = ["extra"] + sources
      strict_deps = true
    end
    if cache.up_to_date?(target, command, sources, env, debug: true, strict_deps: strict_deps)
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
  Environment.new do |env|
    env.add_builder(DebugBuilder)
    if Rscons.vars["new_user_dep"]
      env.depends("foo.o", "new_dep")
    end
    env.DebugBuilder("foo.o", "simple.c")
  end
end
