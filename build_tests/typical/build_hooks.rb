build do
  Environment.new(echo: :command) do |env|
    env.append('CPPPATH' => Rscons.glob('src/**/*/'))
    env.add_build_hook do |build_op|
      if File.basename(build_op[:target]) == "one.o"
        build_op[:vars]["CFLAGS"] << "-O1"
      elsif File.basename(build_op[:target]) == "two.o"
        build_op[:vars]["CFLAGS"] << "-O2"
      end
    end
    env.Program('build_hook.exe', Rscons.glob('src/**/*.c'))
  end
end
