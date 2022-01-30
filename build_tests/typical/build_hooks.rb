default do
  Environment.new(echo: :command) do |env|
    env.append('CPPPATH' => glob('src/**/*/'))
    env.add_build_hook do |builder|
      if File.basename(builder.sources.first) == "one.c"
        builder.vars["CFLAGS"] << "-O1"
      elsif File.basename(builder.sources.first) == "two.c"
        builder.vars["CFLAGS"] << "-O2"
      end
    end
    env.Program('build_hook.exe', glob('src/**/*.c'))
  end
end
