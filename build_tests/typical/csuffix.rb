env do |env|
  env["CSUFFIX"] = %w[.yargh .c]
  env["CFLAGS"] += %w[-x c]
  env["CPPPATH"] += glob("src/**")
  env.Program("program.exe", glob("src/**/*.{c,yargh}"))
end
