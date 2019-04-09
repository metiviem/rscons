build do
  Environment.new do |env|
    env["CPPPATH"] << "src/lib"
    env.Object("file.S", "src/lib/one.c", "CFLAGS" => env["CFLAGS"] + ["-S"])
    libmine = env.SharedLibrary("mine", "file.S")
  end
end
