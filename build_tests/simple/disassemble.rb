env do |env|
  env.Object("simple.o", "simple.c")
  env.Disassemble("simple.txt", "simple.o")
end
