build do
  Environment.new do |env|
    env.Object("simple.o", "simple.c")
    env.Object("two.o", "two.c")
  end
end
