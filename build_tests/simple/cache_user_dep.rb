Rscons::Environment.new do |env|
  env.Program("simple.exe", "simple.c")
  user_deps = File.read("user_deps", mode: "rb").split(" ")
  env.depends("simple.exe", *user_deps)
end
