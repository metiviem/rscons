build do
  Rscons::Environment.new do |env|
    env.Copy("simple.copy", "simple.c")
  end
end
