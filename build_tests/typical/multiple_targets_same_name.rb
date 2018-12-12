Rscons::Environment.new do |env|
  env["CPPPATH"] << "src/two"
  env.Object("one.o", "src/one/one.c")
  env.Object("one.o", "src/two/two.c")
end
