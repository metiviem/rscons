env do |env|
  env.Program("test.exe", glob("*.c"), direct: true)
end
