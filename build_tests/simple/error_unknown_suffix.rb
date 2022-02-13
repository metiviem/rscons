env do |env|
  File.open("foo.xyz", "wb") do |fh|
    fh.puts("hi")
  end
  env.Object("foo.o", "foo.xyz")
end
