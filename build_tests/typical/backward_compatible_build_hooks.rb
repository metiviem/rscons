class MyObject < Rscons::Builder
  def run(options)
    target, sources, cache, env, vars = options.values_at(:target, :sources, :cache, :env, :vars)
    env.run_builder(env.builders["Object"].new(target: target, sources: sources, cache: cache, env: env, vars: vars), target, sources, cache, vars)
  end
end

build do
  Environment.new(echo: :command) do |env|
    env.add_builder(MyObject)
    env.append('CPPPATH' => Rscons.glob('src/**'))
    env.add_build_hook do |build_op|
      if build_op[:builder].name == "MyObject" && build_op[:sources].first =~ %r{one\.c}
        build_op[:vars]["CFLAGS"] << "-O1"
        build_op[:sources] = ['src/two/two.c']
      elsif build_op[:builder].name == "MyObject" && build_op[:target] =~ %r{two\.o}
        new_vars = build_op[:vars].clone
        new_vars["CFLAGS"] << "-O2"
        build_op[:vars] = new_vars
      end
    end
    env.MyObject('one.o', 'src/one/one.c')
    env.MyObject('two.o', 'src/two/two.c')
  end
end
