env do |env|
  env["CPPPATH"] << "src/lib"
  env["SHLD"] = "gcc"
  libmine = env.SharedLibrary("mine", glob("src/lib/*.c"))
  env.Program("test-shared.exe",
              glob("src/*.c"),
              "LIBPATH" => %w[.],
              "LIBS" => %w[mine])
  env.build_after("test-shared.exe", libmine)
  env.Program("test-static.exe",
              glob("src/**/*.c"))
end
