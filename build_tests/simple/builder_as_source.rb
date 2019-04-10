build do
  Environment.new do |env|
    object = env.Object("simple.o", "simple.c")
    env.Program("simple.exe", object)
  end
end
