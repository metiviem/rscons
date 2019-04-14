build do
  Environment.new do |env|
    env["CPPPATH"] << "src/lib"
    libmine = env.SharedLibrary("mine", glob("src/lib/*.cc"))
    env.Program("test-shared.exe",
                glob("src/*.cc"),
                "LIBPATH" => %w[.],
                "LIBS" => %w[mine])
    env.build_after("test-shared.exe", libmine)
    env.Program("test-static.exe",
                glob("src/**/*.cc"))
  end
end
