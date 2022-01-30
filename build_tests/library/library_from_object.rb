default do
  Environment.new do |env|
    env.Program("library.exe", ["lib.a", "three.c"])
    env.Object("two.o", "two.c")
    env.Library("lib.a", ["one.c", "two.o"], 'CPPFLAGS' => ['-Dmake_lib'])
  end
end
