env do |env|
  env["LIBS"] += ["m"]
  env.Program('simple.exe', Dir['*.c'])
end
