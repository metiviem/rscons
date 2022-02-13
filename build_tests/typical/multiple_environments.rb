env do |env|
  env["CPPPATH"] += glob("src/**")
  env.Program("^/prog.exe", glob("src/**/*.c"))
end

env do |env|
  env["CPPPATH"] += glob("src/**")
  env["CCFLAGS"] += %w[-Wall -g]
  env.Program("^/prog-debug.exe", glob("src/**/*.c"))
end
