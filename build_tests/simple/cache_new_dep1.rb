Rscons::Environment.new do |env|
  env.Object("simple.o", "simple.c")
  env.process
  env["LDCMD"] = %w[gcc -o ${_TARGET} simple.o]
  env.Program('simple.exe', [])
end
