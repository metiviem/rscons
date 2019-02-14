build do
  Environment.new do |env|
    env.Program("simple.exe", Dir["*.c"])
    env.add_build_hook do |builder|
      if builder.target.end_with?(".o")
        env.Disassemble("#{builder.target}.txt", builder.target)
      end
    end
  end
end
