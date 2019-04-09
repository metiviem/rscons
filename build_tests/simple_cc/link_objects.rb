build do
  Environment.new do |env|
    env.Object("simple.o", "simple.cc")
    env.Program("simple.exe", "simple.o")
  end
end
