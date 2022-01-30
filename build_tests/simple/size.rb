default do
  Environment.new do |env|
    env.Program("simple.exe", glob("*.c"))
    env.Size("simple.size", "simple.exe")
  end
end
