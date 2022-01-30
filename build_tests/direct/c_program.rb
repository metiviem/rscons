default do
  Environment.new do |env|
    env.Program("test.exe", glob("*.c"), direct: true)
  end
end
