configure do
  check_lib "m"
end

env(echo: :command) do |env|
  env.Program("simple.exe", "simple.c")
end
