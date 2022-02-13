env do |env|
  env.Command("foo", "bar")
  env.Command("bar", "baz")
  env.Command("baz", "foo")
end
