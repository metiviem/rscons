default do
  Environment.new do |env|
    target = env.Program("simple.exe", "simple.c")
    user_deps = File.read("user_deps", mode: "rb").split(" ")
    target.depends(*user_deps)
  end
end
