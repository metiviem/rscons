build do
  Environment.new(echo: :command) do |env|
    env["LD"] = "gcc"
    env["LIBPATH"] += ["libdir"]
    env.Program('simple.exe', Dir['*.c'])
  end
end
