env(echo: :command) do |env|
  env["LD"] = "gcc"
  mkdir_p("libdir")
  env["LIBPATH"] += ["libdir"]
  env.Program('simple.exe', Dir['*.c'])
end
