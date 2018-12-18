build do
  Environment.new do |env|
    env["CPPPATH"] << "src/lib"
    libmine = env.SharedLibrary("mine", Rscons.glob("src/lib/*.cc"))
    env.Program("test-shared.exe",
                Rscons.glob("src/*.cc"),
                "LIBPATH" => %w[.],
                "LIBS" => %w[mine])
    env.build_after("test-shared.exe", libmine.to_s)
    env.Program("test-static.exe",
                Rscons.glob("src/**/*.cc"))
  end
end
