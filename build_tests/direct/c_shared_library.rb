default do
  Environment.new do |env|
    lib = env.SharedLibrary("mylib", ["two.c", "three.c"], direct: true)
    program = env.Program("test.exe", "main.c", "LIBS" => ["mylib"], "LIBPATH" => ["."])
    env.depends(program, lib)
  end
end
