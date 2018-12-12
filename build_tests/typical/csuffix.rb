Rscons::Environment.new do |env|
  env["CSUFFIX"] = %w[.yargh .c]
  env["CFLAGS"] += %w[-x c]
  env["CPPPATH"] += Rscons.glob("src/**")
  env.Program("program.exe", Rscons.glob("src/**/*.{c,yargh}"))
end
