Rscons::Environment.new do |env|
  env["CSUFFIX"] = %w[.yargh .c]
  env["CFLAGS"] += %w[-x c]
  env["CPPPATH"] += Dir["src/**/"]
  env.Program("build_dir.exe", Dir["src/**/*.{c,yargh}"])
end
