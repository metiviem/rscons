build do
  Environment.new do |env|
    env.add_builder(:Checker) do |params|
      target, sources, cache, env, vars = params.values_at(:target, :sources, :cache, :env, :vars)
      unless cache.up_to_date?(target, :Checker, sources, env)
        puts "Checker #{sources.first}" if env.echo != :off
        cache.register_build(target, :Checker, sources, env)
      end
      target
    end
    env.Program("simple.exe", "simple.c")
    env.Checker(:checker, "simple.exe")
  end
end
