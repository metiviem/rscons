Rscons::Environment.new do |env|
  env["CSUFFIX"] = %w[.yargh .c]
  env["CFLAGS"] += %w[-x c]
  env["CPPPATH"] += Rscons.glob("src/**")
  env.Program("build_dir.exe", Rscons.glob("src/**/*.{c,yargh}"))
end
