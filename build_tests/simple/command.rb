env(echo: :command) do |env|
  env["LD"] = "gcc"
  env.Program('simple.exe', Dir['*.c'])
end
