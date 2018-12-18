build do
  Rscons::Environment.new do |env|
    env.Command("foo", "foo")
  end
end
