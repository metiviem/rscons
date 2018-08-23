Rscons::Environment.new(echo: :command) do |env|
  env.append('CPPPATH' => Rscons.glob('src/**/*/'))
  env.build_dir(%r{^src/([^/]+)/}, 'build_\\1/')
  env.add_build_hook do |build_op|
    if build_op[:target] =~ %r{build_one/.*\.o}
      build_op[:vars]["CFLAGS"] << "-O1"
    elsif build_op[:target] =~ %r{build_two/.*\.o}
      build_op[:vars]["CFLAGS"] << "-O2"
    end
  end
  env.Program('build_hook.exe', Rscons.glob('src/**/*.c'))
end
