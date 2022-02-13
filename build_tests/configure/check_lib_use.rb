configure do
  check_lib "m", use: :m
end

env(echo: :command) do |env|
  env.Copy("test1.c", "simple.c")
  env.Program("test2.exe", "test1.c")
end

env(echo: :command, use: %w[m]) do |env|
  env.Copy("test2.c", "simple.c")
  env.Program("test2.exe", "test2.c")
end
