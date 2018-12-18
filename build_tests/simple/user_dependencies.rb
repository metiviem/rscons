build do
  Rscons::Environment.new do |env|
    program = env.Program("simple.exe", Dir["*.c"])
    env.depends(program, "program.ld")
  end
end
