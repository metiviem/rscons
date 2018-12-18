build do
  env1 = Environment.new(echo: :command) do |env|
    env['CFLAGS'] = '-O2'
    env.add_build_hook do |build_op|
      build_op[:vars]['CPPFLAGS'] = '-DSTRING="Hello"'
    end
    env.add_post_build_hook do |build_op|
      $stdout.puts "post #{build_op[:target]}"
    end
    env.Program('program.exe', Dir['src/*.c'])
  end

  env2 = env1.clone do |env|
    env.Program('program2.exe', Dir['src/*.c'])
  end
end
