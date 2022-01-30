default do
  Environment.new do |env|
    env["CPPPATH"] << "src/lib"
    libmine = env.SharedLibrary("mine", glob("src/lib/*.d"))
    env.Program("test-shared.exe",
                glob("src/*.c"),
                "LIBPATH" => %w[.],
                "LIBS" => %w[mine])
    env.build_after("test-shared.exe", libmine)
  end
end
