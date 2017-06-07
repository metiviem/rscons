Rscons::Environment.new do |env|
  env["CPPPATH"] << "src/lib"
  libmine = env.SharedLibrary("libmine", Dir["src/lib/*.cc"])
  env.Program("test-shared.exe",
              Dir["src/*.cc"],
              "LIBPATH" => %w[.],
              "LIBS" => %w[mine])
  env.build_after("test-shared.exe", libmine.to_s)
  env.Program("test-static.exe",
              Dir["src/**/*.cc"])
end
