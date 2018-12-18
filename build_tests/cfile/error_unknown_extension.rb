build do
  Environment.new do |env|
    env.CFile("file.c", "foo.bar")
  end
end
