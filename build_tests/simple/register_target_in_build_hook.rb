Rscons::Environment.new do |env|
  env.Program("simple.exe", Dir["*.c"])
  env.add_build_hook do |build_op|
    if build_op[:target].end_with?(".o")
      env.Disassemble("#{build_op[:target]}.txt", build_op[:target])
    end
  end
end
