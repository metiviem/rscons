default do
  env do |env|
    env.Program('simple.exe', Dir['*.c'])
  end
end
