env do |env|
  env.Object("simple.o", "simple.c")
  env["LDCMD"] = %w[gcc -o ${_TARGET} simple.o]
  env.Program('simple.exe', ["simple.o"])
end
