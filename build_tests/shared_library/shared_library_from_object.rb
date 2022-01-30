default do
  Environment.new do |env|
    env["CPPPATH"] << "src/lib"
    env.SharedObject("one.o", "src/lib/one.c")
    libmine = env.SharedLibrary("mine", ["one.o", "src/lib/two.c"])
  end
end
