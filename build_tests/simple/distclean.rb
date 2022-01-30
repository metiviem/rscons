default do
  Environment.new do |env|
    env.Object("simple.o", "simple.c")
  end
end
