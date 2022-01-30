default do
  Environment.new(echo: :command) do |env|
    env.append("CPPPATH" => glob("src/**"))
    FileUtils.mkdir_p(env.build_root)
    FileUtils.mv("src/one/one.c", env.build_root)
    FileUtils.mv("src/two/two.c", Rscons.application.build_dir)
    env.Object("^/one.o", "^/one.c")
    env.Program("^^/program.exe", ["^/one.o", "^^/two.c"])
  end
end
