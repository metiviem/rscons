build do
  Environment.new do |env|
    env["CPPPATH"] += glob("src/**")
    env.Program("^/prog.exe", glob("src/**/*.c"))
  end

  Environment.new do |env|
    env["CPPPATH"] += glob("src/**")
    env["CCFLAGS"] += %w[-Wall -g]
    env.Program("^/prog-debug.exe", glob("src/**/*.c"))
  end
end
