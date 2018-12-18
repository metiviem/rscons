build do
  Environment.new do |env|
    env["CPPPATH"] << "src/lib"
    env["SHLD"] = "gcc"
    libmine = env.SharedLibrary("mine", Rscons.glob("src/lib/*.c"))
    env.Program("test-shared.exe",
                Rscons.glob("src/*.c"),
                "LIBPATH" => %w[.],
                "LIBS" => %w[mine])
    env.build_after("test-shared.exe", libmine.to_s)
    env.Program("test-static.exe",
                Rscons.glob("src/**/*.c"))
  end
end
