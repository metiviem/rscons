Rscons::Environment.new do |env|
  env["CPPPATH"] << "src/lib"
  libmine = env.SharedLibrary("libmine", Dir["src/lib/*.d"])
  env.Program("test-shared.exe",
              Dir["src/*.c"],
              "LIBPATH" => %w[.],
              "LIBS" => %w[mine])
  env.build_after("test-shared.exe", libmine.to_s)
end
