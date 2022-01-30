default do
  Environment.new do |env|
    env.produces("foo", "bar")
  end
end
