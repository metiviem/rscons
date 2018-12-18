build do
  Rscons::Environment.new do |env|
    env["LIBS"] += ["c"]
    env.Program('simple.exe', Dir['*.c'])
  end
end
