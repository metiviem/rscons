class DebugBuilder < Rscons::Builder
  def run(options)
    target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
    command = %W[gcc -c -o #{target} #{sources.first}]
    if ENV["command_change"]
      command += %w[-Wall]
    end
    if ENV["new_dep"]
      sources += ["extra"]
    end
    if ENV["strict_deps1"]
      sources += ["extra"]
      strict_deps = true
    end
    if ENV["strict_deps2"]
      sources = ["extra"] + sources
      strict_deps = true
    end
    unless cache.up_to_date?(target, command, sources, env, debug: true, strict_deps: strict_deps)
      desc = "#{self.class.name} #{target}"
      return false unless env.execute(desc, command)
      cache.register_build(target, command, sources, env)
    end
    target
  end
end

Rscons::Environment.new do |env|
  env.add_builder(DebugBuilder.new)
  if ENV["new_user_dep"]
    env.depends("foo.o", "new_dep")
  end
  env.DebugBuilder("foo.o", "simple.c")
end
