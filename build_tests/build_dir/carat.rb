Rscons::Environment.new(echo: :command) do |env|
  env.append('CPPPATH' => Rscons.glob('src/**').sort)
  FileUtils.mkdir_p(env.build_root)
  FileUtils.mv("src/one/one.c", env.build_root)
  env.Object("^/one.o", "^/one.c")
  env.Program("build_dir.exe", Rscons.glob('src/**/*.c') + ["^/one.o"])
end
